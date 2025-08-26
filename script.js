/* Only used when debugging: 
window.onerror = (msg, url, line, column, error) => {
  const message = {
    message: msg,
    url: url,
    line: line,
    column: column,
    error: JSON.stringify(error)
  }

  if (window.webkit) {
   window.webkit.messageHandlers.aShell.postMessage('JS Error:' + msg + ' message: ' + error.message + ' stack: ' + error.stack + '\n');
  } else {
    console.log("Error:", message);
  }
};
*/

//
// functions to deal with executeJavaScript: 
function print(printString) {
	window.webkit.messageHandlers.aShell.postMessage('print:' + printString);
}
function println(printString) {
	window.webkit.messageHandlers.aShell.postMessage('print:' + printString + '\n');
}
function print_error(printString) {
	window.webkit.messageHandlers.aShell.postMessage('print_error:' + printString);
}

function luminance(color) {
	var colorArray = lib.colors.crackRGB(color);
	return colorArray[0] * 0.2126 + colorArray[1] * 0.7152 + colorArray[2] *  0.0722;
}

function initContent(io) {
	const ver = lib.resource.getData('libdot/changelog/version');
	const date = lib.resource.getData('libdot/changelog/date');
	const pkg = `libdot ${ver} (${date})`;
};

function isInteractive(commandString) {
	// If the command is interactive or contains interactive commands, set the flag,
	// forward all keyboard input, let them deal with command history.
	// Commands that call CPR (Cursor Position Request) are not in the list because we detect them separately
	// (vim, ipython, ptpython, jupyter-console...) (see hterm.VT.CSI['n'])
	// ssh and ssh-keygen (new version) are both interactive. So is scp. sftp is interactive until connected.
	// vim is back on the list because it can be called by the Files app, and we have initialization issues.
	let interactiveRegexp = /^less|^more|^vim|^ssh|^scp|^sftp|\|&? *less|\|&? *more|^man|^pico/;
	return interactiveRegexp.test(commandString) 
	// It's easier to match a regexp, then take the negation than to test a regexp that does not contain a pattern:
	// This is disabled for now, but kept in case it can become useful again.
	// let notInteractiveRegexp = /^ssh-keygen/;
	// return interactiveRegexp.test(commandString) && !notInteractiveRegexp.test(commandString);
}

// standard functions (terminal, autocomplete, etc)
var lastDirectory = '';
var lastOnlyDirectories = false;
var fileList = [];
var currentCommandCursorPosition;
var autocompleteList = []; 
var autocompleteOn = false;
var autocompleteIndex = 0;

function disableAutocompleteMenu() {
	printString('');
	autocompleteOn = false;
	autocompleteList = [];
	autocompleteIndex = 0;
	fileList = '';
	lastDirectory = '';
	lastOnlyDirectories = false;
}

function cleanupLastLine() {
	// console.log("Before: " + window.printedContent);
	// Clean up the last line (it can contain a lot of control characters, up arrow, down arrow, etc):
	var lastNewline = window.printedContent.lastIndexOf("\n");
	var lastLine = window.printedContent.substr(lastNewline +1 ); // skip past before-last \n
	window.printedContent = window.printedContent.substr(0, lastNewline); // remove last \n
	var emptyLastLine = false;
	if (lastLine.length == 0) {
		emptyLastLine = true;
		lastNewline = window.printedContent.lastIndexOf("\n");
		lastLine = window.printedContent.substr(lastNewline +1 ); // skip past before-last \n
		window.printedContent = window.printedContent.substr(0, lastNewline); // remove last line
	}
	// console.log("Last line, before : " + lastLine);
	if (window.commandRunning == '') {
		lastLine = "\n\r\x1b[0m\x1b[39;49m" + window.promptMessage + window.term_.io.currentCommand ;
	} else {
		// promptMessage has been set in updatePromptPosition
		lastLine = window.promptMessage + window.term_.io.currentCommand ;
	}
	// console.log("Last line, after : " + lastLine);
	// This needs thinking. There's a "\n" missing after that.
	window.printedContent += lastLine; 
	if (emptyLastLine) {
		window.printedContent += '\r\n';
	}
	// console.log("After: " + window.printedContent);

}

function isLetter(c) {
	// TODO: extension for CJK characters (hard)
	return (c.toLowerCase() != c.toUpperCase());
}

// Required because printedContent now arrives after the first prompt has been printed.
function setWindowContent(string) {
	if (window.printedContent != '') {
		return;
	}
	window.term_.wipeContents();
	window.printedContent = '';
	window.term_.io.print(string);
	if (!string.endsWith(window.promptMessage)) {
		printPrompt();
	} else {
		// If the string ends with the prompt, no need to print it again.
		window.commandRunning = '';
		window.interactiveCommandRunning = false;
		window.term_.reportFocus = false; // That was causing ^[[I sometimes
	}
	window.term_.io.currentCommand = '';
}

function printPrompt() {
	// prints the prompt and initializes all variables related to prompt position
	window.term_.io.print('\x1b[0m\x1b[39;49m');  // default font, default color
	// cut window.printedContent if it gets too large:
	if (window.printedContent.length > 30000) {
		window.printedContent = window.printedContent.substring(5000);
	}
	if (window.commandRunning == '') {
		window.term_.io.print(window.promptMessage); 
		window.commandRunning = '';
		window.term_.io.currentCommand = '';
		window.interactiveCommandRunning = false;
		window.term_.reportFocus = false; // That was causing ^[[I sometimes
	} else {
		window.webkit.messageHandlers.aShell.postMessage('input:' + '\n');
	}
}

function updatePromptPosition() {
	window.promptEnd = window.term_.screen_.cursorPosition.column;
	var lastNewline = window.printedContent.lastIndexOf("\r");
	var lastLine = window.printedContent.substr(lastNewline +1 ); // skip past last \n
	if (lastLine.length == 0) { 
		lastNewline = window.printedContent.lastIndexOf("\n");
		lastLine = window.printedContent.substr(lastNewline +1 );
	}
	if ((lastLine.length == 1) && ((lastLine[0] == '\n') || (lastLine[0] == '\r'))) {
		lastLine = '';
	} else if (window.commandRunning != '') {
		window.promptMessage = lastLine; // store current command prompt message.
	}
	// required because some commands can take several lines, especially on a phone.
	window.promptLine = window.term_.screen_.cursorPosition.row;
	window.promptScroll = window.term_.scrollPort_.getTopRowIndex();
	currentCommandCursorPosition = 0; 
}

// returns the actual width, on screen, of a string, including with emojis.
// This is different from lib.wc.strWidth, which returns the length in characters. 
// A family emoji has strWidth = 8, screenWidth = 2
function screenWidth(str) {
  let rv = 0;
  let afterJoiner = false;
  let isModifier = false;
  	// modifiers (skin color) are *after* the emoji they change, zero-width-joiners are *between* two emojis.

  for (let i = 0; i < str.length;) {
    const codePoint = str.codePointAt(i);
	const charAtCodePoint = String.fromCodePoint(codePoint);
	isModifier = (charAtCodePoint.match(/\p{Emoji_Modifier}/gu) != null);
    const width = lib.wc.charWidth(codePoint);
    if (width < 0) {
      return -1;
    }
    if ((!afterJoiner) && (!isModifier)) {
      rv += width;
	}
	afterJoiner = (codePoint == 8205);
    i += (codePoint <= 0xffff) ? 1 : 2;
  }

  return rv;
}

// prints a string and move the rest of the command around, even if it is over multiple lines
// we use lib.wc.strWidth instead of length because of multiple-width characters (CJK, mostly).
// TODO: get correct character width for emojis.
function printString(string) {
	var l = lib.wc.strWidth(string);

	var currentCommand = window.term_.io.currentCommand;
	// clear the rest of the line, then reprint. 
	window.term_.io.print('\x1b[0J'); // delete display after cursor
	window.term_.io.print(string);

	// print remainder of command line
	window.term_.io.print(currentCommand.slice(currentCommandCursorPosition, currentCommand.length));
	// move cursor back to where it was (don't use term.screen_.cursorPosition):
	var endOfCommand = currentCommand.slice(currentCommandCursorPosition, currentCommand.length);
	var endOfCommandWidth = lib.wc.strWidth(endOfCommand);
	if ((lib.wc.strWidth(currentCommand) + lib.wc.strWidth(window.promptMessage) + 1 >= window.term_.screenSize.width) && (endOfCommandWidth == 0)) {
		window.term_.io.print(' ');
		endOfCommandWidth = 1;
	} 
	// window.term_.io.print has issues (known) when a wide char crosses the end of line. Annoying.
	for (var i = 0; i < endOfCommandWidth; i++) {
		window.term_.io.print('\b'); 
	}
}

// prints a string for autocomplete and move the rest of the command around, even if it is over multiple lines.
// keep the command as it is until autocomplete has been accepted.
function printAutocompleteString(string) {
	var currentCommand = window.term_.io.currentCommand;
	// clear entire buffer, then reprint
	window.term_.io.print('\x1b[0J'); // delete display after cursor
	if (luminance(window.term_.getBackgroundColor()) < luminance(window.term_.getForegroundColor())) {
		// We are in dark mode. Use yellow font for higher contrast
		window.term_.io.print('\x1b[33m'); // yellow

	} else {
		window.term_.io.print('\x1b[32m'); // green
	}
	window.term_.io.print(string); 
	window.term_.io.print('\x1b[39m'); // back to normal foreground color
	// print remainder of command line
	window.term_.io.print(currentCommand.slice(currentCommandCursorPosition, currentCommand.length))
	// move cursor back to where it was (don't use term.screen_.cursorPosition):
	// don't use length because of multiple-byte chars.
	var endOfCommand = currentCommand.slice(currentCommandCursorPosition, currentCommand.length);
	var wcwidth = lib.wc.strWidth(endOfCommand) + lib.wc.strWidth(string);
	for (var i = 0; i < wcwidth; i++) {
		window.term_.io.print('\b'); 
	}
}

// behaves as if delete key is pressed.
function deleteBackward() {
	if (currentCommandCursorPosition <= 0) {
		return;
	}

	var previousCursorPosition = 0;
	var currentChar;
	for (const v of window.term_.io.currentCommand) {
		if (previousCursorPosition + v.length >= currentCommandCursorPosition) {
			currentChar = v;
			break;
		}
		previousCursorPosition += v.length;
	}
	const currentCharWidth = lib.wc.strWidth(currentChar);
	for (let i = 0; i < currentCharWidth; i++) {
		window.term_.io.print('\b'); // move cursor back n chars, across lines
	}

	window.term_.io.print('\x1b[0J'); // delete display after cursor

	// print remainder of command line
	const endOfCommand = window.term_.io.currentCommand.slice(currentCommandCursorPosition);
	window.term_.io.print(endOfCommand);

	// move cursor back to where it was (don't use term.screen_.cursorPosition):
	const wcwidth = lib.wc.strWidth(endOfCommand);
	for (let i = 0; i < wcwidth; i++) {
		window.term_.io.print('\b');
	}

	// remove character from command at current position:
	window.term_.io.currentCommand = window.term_.io.currentCommand.slice(0, previousCursorPosition) + endOfCommand;
	currentCommandCursorPosition = previousCursorPosition;
}

function pickCurrentValue() {
	var currentCommand = window.term_.io.currentCommand;
	var cursorPosition = window.term_.screen_.cursorPosition.column - window.promptEnd;
	selected = autocompleteList[autocompleteIndex]; 
	printString(selected);
	window.term_.io.currentCommand = currentCommand.slice(0, currentCommandCursorPosition) + selected + 
		currentCommand.slice(currentCommandCursorPosition, currentCommand.length);
	// is not enough to push the rest of the command if it's longer than a line
	currentCommandCursorPosition += selected.length;
	disableAutocompleteMenu();
}

// called once the list of files has been updated, asynchronously. 
function updateFileMenu() {
	var cursorPosition = window.term_.screen_.cursorPosition.column - window.promptEnd;
	updateAutocompleteMenu(window.term_.io, cursorPosition);
}

function updateAutocompleteMenu(io, cursorPosition) {
	var lastFound = '';
	// string to use for research: from beginning of line to cursor position
	var rootForMatch = io.currentCommand.slice(0, currentCommandCursorPosition);
	var predicate = rootForMatch;
	var n = predicate.lastIndexOf("|");
	var lastPipePosition = 0; 
	if (n < predicate.length) {
		lastPipePosition = n + 1;
		predicate = predicate.substr(n + 1);
	}
	n = predicate.lastIndexOf(" ");
	while ((n > 0) && (predicate[n-1] == "\\")) { 
		// escaped space
		n = predicate.lastIndexOf(" ", n - 1);
	}
	if (n < predicate.length) {
		predicate = predicate.substr(n + 1);
	}
	n = predicate.lastIndexOf(">");
	if (n < predicate.length) {
		predicate = predicate.substr(n + 1);
	}
	if (predicate[0] == '-') return; // arguments to function, no autocomplete
	// we have the string to use for matching (predicate). Is it a file or a command?
	var beforePredicate = rootForMatch.substr(0, rootForMatch.lastIndexOf(predicate));
	// remove all trailing spaces:
	while ((beforePredicate.length > 0) && (beforePredicate.slice(-1) == " ")) {
		beforePredicate = beforePredicate.slice(0, beforePredicate.length - 1)
	}
	autocompleteIndex = 0; 
	autocompleteList = [];
	var numFound = 0; 
	var matchToCommands = false;
	var listDirectories = false;
	var matchingWithZ = false;
	if (beforePredicate.length == 0) {
		matchToCommands = true; // beginning of line, must be a command
	} else if (beforePredicate.slice(-1) == "|") {
		matchToCommands = true; // right after a pipe, must be a command
	} 
	// Now extract the command after the pipe:
	var beforePredicate = rootForMatch.substr(lastPipePosition, rootForMatch.lastIndexOf(predicate));
	// remove all trailing spaces:
	while ((beforePredicate.length > 0) && (beforePredicate.slice(-1) == " ")) {
		beforePredicate = beforePredicate.slice(0, beforePredicate.length - 1)
	}
	// remove all beginning spaces:
	while ((beforePredicate.length > 0) && (beforePredicate[0] == " ")) {
		beforePredicate = beforePredicate.slice(1)
	}
	if (beforePredicate === "cd") {
		listDirectories = true;
	} else if (beforePredicate === "z") {
		// Specific action for z + tab. *Very* specific.
		if (fileList.length == 0) {
			window.webkit.messageHandlers.aShell.postMessage('listDirectoriesForZ:' + predicate);
			return;
		} else { 
			// Erase the "z" command (to the start of beforePredicate), replace with "cd"
			const wcwidth = lib.wc.strWidth(predicate);
			for (let i = 0; i < wcwidth; i++) {
				deleteBackward()
			}
			var toDelete = window.term_.io.currentCommand.lastIndexOf("z");
			var toDeleteStr = window.term_.io.currentCommand.slice(toDelete);
			const wcwidth2 = lib.wc.strWidth(toDeleteStr);
			for (let i = 0; i < wcwidth2; i++) {
				deleteBackward()
			}
			printString("cd ");
			io.currentCommand = io.currentCommand.slice(0, currentCommandCursorPosition) + "cd " + 
				io.currentCommand.slice(currentCommandCursorPosition, io.currentCommand.length);
			currentCommandCursorPosition += "cd ".length;
			if (fileList.length == 1) {
				// only one solution: print it
				printString(fileList[0]);
				io.currentCommand = io.currentCommand.slice(0, currentCommandCursorPosition) + fileList[0] + 
					io.currentCommand.slice(currentCommandCursorPosition, io.currentCommand.length);
				currentCommandCursorPosition += fileList[0].length; 
				autocompleteOn = false;
				return
			} else {
				// multiple solutions, print all:
				for (var i = 0, len = fileList.length; i < len; i++) {
					autocompleteList[numFound] = fileList[i]; 
					lastFound = value; 
					numFound += 1;
				}
				autocompleteOn = true;
				autocompleteIndex = 0;
				printAutocompleteString(autocompleteList[autocompleteIndex]);
				return;
			}
		}
		return;
	}
	// otherwise, it's probably a file
	var file = '';
	var directory = '.';
	// Compute list of files from current directory:
	if ((predicate[0] == "~") && (predicate.lastIndexOf("/") == -1)) {
		// string beginning with ~, with no / at the end: it's a bookmark.
		directory = '';
		file = predicate;
		// recompute if the directory listed has changed, or if we now want files instead of directories:
		if ((lastDirectory != '~bookmarkNames') || (lastOnlyDirectories != listDirectories)) {
			// asynchronous communication. Will have to execute the rest of the command too.
			if (listDirectories) {
				window.webkit.messageHandlers.aShell.postMessage('listBookmarksDir:');
			} else {
				window.webkit.messageHandlers.aShell.postMessage('listBookmarks:');
			}
		}
	} else {
		// compute list of files from local directory
		var lastSlash = predicate.lastIndexOf("/");
		if ((predicate.length > 0) && (lastSlash > 0) && (lastSlash < predicate.length)) {
			var directory = predicate.substr(0, lastSlash); // include "/" in directory
			file = predicate.substr(lastSlash + 1); // don't include "/" in file name
		} else {
			directory = ".";
			file = predicate;
		}
		// recompute if the directory listed has changed, or if we now want files instead of directories:
		if ((directory != lastDirectory) ||  (lastOnlyDirectories != listDirectories)){
			// asynchronous communication. Will have to execute the rest of the command too.
			if (listDirectories) {
				// Only directories, include bookmarks for directories
				window.webkit.messageHandlers.aShell.postMessage('listDirectoryDir:' + directory);
			} else {
				window.webkit.messageHandlers.aShell.postMessage('listDirectory:' + directory);
			}
		}
	}
	if (matchToCommands) { 
		// First, match command with history:
		for (var i = 0 , len = window.commandArray.length; i < len ; i++) {
			if (window.commandArray[i].startsWith(predicate)) {
				var value = window.commandArray[i].replace(predicate, ""); 
				autocompleteList[numFound] = value;
				lastFound = value; 
				numFound += 1;
			}
		}
		// only keep the last version of the command from history:
		unique = autocompleteList.filter((v,i,a) => a.lastIndexOf(v) == i);
		autocompleteList = unique;
		// Stop on latest command matching, up = history, down = commands.
		numFound = autocompleteList.length;
		if (numFound > 0) {
			autocompleteIndex = autocompleteList.length - 1;
		}
		for (var i = 0, len = commandList.length; i < len; i++) {
			if (commandList[i].startsWith(predicate)) {
				var value = commandList[i].replace(predicate, "") + ' '; // add a space at the end if it's a command; 
				autocompleteList[numFound] = value;
				lastFound = value; 
				numFound += 1;
			}
		}
	} 
	// Then add list of files from local directory:
	if ((predicate[0] == "~") && (predicate.lastIndexOf("/") == -1)) {
		// string beginning with ~, with no / at the end: it's a bookmark.
		directory = '';
		file = predicate;
		if (lastDirectory == '~bookmarkNames') {
			// First, remove predicate from the autocomplete list:
			for (var i = 0, len = fileList.length; i < len; i++) {
				if (fileList[i].startsWith(file)) {
					var value = fileList[i].replace(file, "")
					autocompleteList[numFound] = value; 
					lastFound = value; 
					numFound += 1;
				}
			}
		} 
	} else {
		if ((predicate[0] == "/") && (predicate.lastIndexOf("/") == 0)) {
			// special case for root
			directory = "/";
			file = predicate.substr(1);
			// This will only work for shortcuts expansion:
		} else {
			var lastSlash = predicate.lastIndexOf("/");
			if ((predicate.length > 0) && (lastSlash > 0) && (lastSlash < predicate.length)) {
				var directory = predicate.substr(0, lastSlash); // include "/" in directory
				file = predicate.substr(lastSlash + 1); // don't include "/" in file name
			} else {
				directory = ".";
				file = predicate;
			}
		}
		// Need to get list of files from directory. 
		if ((directory == lastDirectory) && (lastOnlyDirectories == listDirectories)) {
			// First, remove 
			for (var i = 0, len = fileList.length; i < len; i++) {
				if (fileList[i].startsWith(file)) {
					var value = fileList[i].replace(file, "")
					autocompleteList[numFound] = value; 
					lastFound = value; 
					numFound += 1;
				}
			}
		}
	}
	// substring of io.currentCommand, ending at currentCommandCursorPosition, going back until first space or "/"
	// list to use for autocomplete = commandList if at beginning of line (modulo spaces) or after | (module spaces)
	// list of files inside directory otherwise. e.g. "../Library/Preferences/" (going back until next space)
	// TODO: no autocomplete on file for commands that don't operate on files (difficult)
	if (numFound > 1) {
		// If list is not empty:
		// Find largest starting substring:
		if (((directory == lastDirectory) && (lastOnlyDirectories == listDirectories)) 
				|| ((lastDirectory == '~bookmarkNames') && (predicate[0] == "~") && (lastOnlyDirectories == listDirectories))) {
			var commonSubstring = ''
			for (var l = 1; l < autocompleteList[0].length; l++) {
				substring =  autocompleteList[0].substr(0, l)
				var contained = true
				for (var i = 0, len = autocompleteList.length; i < len; i++) {
					if (!autocompleteList[i].startsWith(substring)) {
						contained = false;
						break;
					}
				}
				if (contained) { 
					commonSubstring = substring;
				} else {
					break;
				}
			}
			if (commonSubstring.length > 0) {
				printString(commonSubstring);
				io.currentCommand = io.currentCommand.slice(0, currentCommandCursorPosition) + commonSubstring + 
					io.currentCommand.slice(currentCommandCursorPosition, io.currentCommand.length);
				currentCommandCursorPosition += commonSubstring.length;
				for (var i = 0, len = autocompleteList.length; i < len; i++) {
					var value = autocompleteList[i].replace(commonSubstring, "")
					autocompleteList[i] = value; 
				}
			}
			//
			autocompleteOn = true;
			// Don't display files starting with "." first (they're in the list, but we don't start with them)
			// Don't do this with directories because we already sorted them
			if ((file.length == 0) && (!listDirectories)) {
				while ((autocompleteList[autocompleteIndex][0] == ".") && (autocompleteIndex < autocompleteList.length - 1)) {
					autocompleteIndex += 1;
				} 
				if (autocompleteIndex == autocompleteList.length - 1) {
					// directory with only ".*" files
					autocompleteIndex = 0;
				}
			}
			printAutocompleteString(autocompleteList[autocompleteIndex]);
		}
	} else {
		if (numFound == 1) {
			if (((directory == lastDirectory) && (lastOnlyDirectories == listDirectories))
				|| ((lastDirectory == '~bookmarkNames') && (predicate[0] == "~") && (lastOnlyDirectories == listDirectories))) {
				printString(lastFound);
				io.currentCommand = io.currentCommand.slice(0, currentCommandCursorPosition) + lastFound + 
					io.currentCommand.slice(currentCommandCursorPosition, io.currentCommand.length);
				currentCommandCursorPosition += lastFound.length;
			}
		}
		autocompleteOn = false;
		disableAutocompleteMenu(); 
	}
}

function setupHterm() {
	const term = new hterm.Terminal();
	// Default monospaced fonts installed: Menlo and Courier. 
	term.prefs_.set('cursor-shape', window.cursorShape); 
	term.prefs_.set('font-family', window.fontFamily);
	term.prefs_.set('font-size', window.fontSize); 
	term.prefs_.set('foreground-color', window.foregroundColor);
	term.prefs_.set('background-color', window.backgroundColor);
	term.prefs_.set('cursor-color', window.cursorColor);
	term.prefs_.set('cursor-blink', false); 
	term.prefs_.set('enable-clipboard-notice', false); 
	term.prefs_.set('use-default-window-copy', false); // true: works but adds \r at each new line. 
	// false, but with our own copySelectionToClipboard: works.
	term.prefs_.set('clear-selection-after-copy', true); 
	term.prefs_.set('copy-on-select', false);
	term.prefs_.set('audible-bell-sound', '');
	term.prefs_.set('receive-encoding', 'utf-8'); 
	term.prefs_.set('meta-sends-escape', 'false'); 
	term.prefs_.set('allow-images-inline', true);

	term.setReverseWraparound(true);
	term.setWraparound(true);
	//
	term.onCut = function(e) { 
		var text = this.getSelectionText();  
		// compose events tend to create a selection node with range, which breaks insertion:
		if (text == null) { 
			// TODO: force the HTML cursor to go back to the actual cursor position (HOW?)
			this.document_.getSelection().collapse(this.scrollPort_.getScreenNode());
			this.syncCursorPosition_();
			return false;
		}
		// We also need to remove it from the command line -- if it is in.
		var startRow = this.scrollPort_.selection.startRow.rowIndex;
		var endRow = this.scrollPort_.selection.endRow.rowIndex;
		if ((startRow >= window.promptScroll + window.promptLine ) &&
			(endRow >= window.promptScroll + window.promptLine )) {
			// the selected text is inside the current command line: we can cut it.
			// startOffset = position of selection from start of startRow (not necessarily start of command)
			var startOffset = this.scrollPort_.selection.startOffset;
			// endOffset = position of selection from start of endRow (not used)
			var endOffset = this.scrollPort_.selection.endOffset;
			var startPosition = this.io.currentCommand.indexOf(text)
			var xcursor = startOffset;
			if (startPosition != -1) {
				// check if text is inside currentCommand *once*, if yes, just remove it.
				if (this.io.currentCommand.lastIndexOf(text) == startPosition) {
					this.io.currentCommand =  this.io.currentCommand.slice(0, startPosition) + this.io.currentCommand.slice(startPosition + text.length, this.io.currentCommand.length);
				} else {
					const startNode = this.scrollPort_.selection.startNode;
					const endNode = this.scrollPort_.selection.endNode
					const numLines = (startRow - window.promptScroll - window.promptLine);
					var fullOffset = 0;
					if (this.scrollPort_.selection.startRow.childNodes[0] == startNode) {
						// easy case, we're on the first node.
						startOffset += numLines * this.screenSize.width - window.promptEnd;
						var cutText = this.io.currentCommand.slice(startOffset, startOffset + text.length); 
						if (cutText == text) {
							startPosition = startOffset;
							this.io.currentCommand =  this.io.currentCommand.slice(0, startPosition) + this.io.currentCommand.slice(startPosition + text.length, this.io.currentCommand.length); 
						}
					} else {
						// Multiple nodes, the selected text is not on the first node.
						// We must advance inside currentCommand by at least this much:
						startPosition = numLines * this.screenSize.width - window.promptEnd;
						startPosition += this.scrollPort_.selection.startRow.childNodes[0].length;
						var cutText = this.io.currentCommand.slice(startPosition, this.io.currentCommand.length); 
						for (let i = 1; i < this.scrollPort_.selection.startRow.childNodes.length; i++) {
							const node = this.scrollPort_.selection.startRow.childNodes[i];
							if (node.nodeName == "#text") {
								if (startNode != node) {
									startPosition += node.data.length;
								} else {
									startPosition += startOffset;
									break;
								}
							} else {
								var foundNode = false;
								for (let j = 0; j < node.childNodes.length; j++) {
									const secondNode = node.childNodes[j];
									if (startNode != secondNode) {
										startPosition += secondNote.data.length;
									} else {
										startPosition += startOffset;
										foundNode = true;
										break;
									}
								}
								if (foundNode) {
									break;
								}
							}
						}
						var cutText = this.io.currentCommand.slice(startPosition, startPosition + text.length); 
						if (cutText == text) {
							this.io.currentCommand =  this.io.currentCommand.slice(0, startPosition) + this.io.currentCommand.slice(startPosition + text.length, this.io.currentCommand.length); 
						} else {
							// This happens too often. 
							// TODO: make sure we don't cut "newline" instead of actual text.
							// Do not cut if we don't agree on what to cut
							if (e != null) {
								e.preventDefault();
							}
							return false; 
						}
					}
				}
				// Move cursor to startLine, startOffset
				// We redraw the command ourselves because iOS removes extra spaces around the text.
				// var scrolledLines = window.promptScroll - term.scrollPort_.getTopRowIndex();
				// io.print('\x1b[' + (window.promptLine + scrolledLines + 1) + ';' + (window.promptEnd + 1) + 'H'); // move cursor to position at start of line
				xcursor = window.promptEnd + startPosition;
				while (xcursor > this.screenSize.width) {
					xcursor -= this.screenSize.width;
				}
				currentCommandCursorPosition = startPosition
				var ycursor = startRow - this.scrollPort_.getTopRowIndex();
				this.io.print('\x1b[' + (ycursor + 1) + ';' + (xcursor + 1) + 'H'); // move cursor to new position 
				this.io.print('\x1b[0J'); // delete display after cursor
				var endOfCommand = this.io.currentCommand.slice(startPosition, this.io.currentCommand.length); 
				this.io.print(endOfCommand); 
				this.io.print('\x1b[' + (ycursor + 1) + ';' + (xcursor + 1) + 'H'); // move cursor back to new position 
				window.webkit.messageHandlers.aShell.postMessage('copy:' + text); // copy the text to clipboard. We can't use JS fonctions because we removed the text.
				e.preventDefault();
				return true;
			} else {
				window.webkit.messageHandlers.aShell.postMessage("Really cannot find text = " + text + " in " + this.io.currentCommand); 
				// Do not cut if we don't agree on what to cut
				if (e != null) {
					e.preventDefault();
				}
				return false; 
			}
		}
		// Do not cut if we are outside the command line:
		if (e != null) {
			e.preventDefault();
			return false;
		}
	};

	// 
	term.onTerminalReady = function() {
		const io = this.io.push();
		io.onVTKeystroke = (string) => {
			if (window.controlOn) {
				// on-screen control is On
				// produce string = control + character 
				// Replace on-screen-control + arrow with alt + arrow (already present in code)
				switch (string) {
					case String.fromCharCode(27) + "[A":  // Up arrow
					case String.fromCharCode(27) + "OA":  // Up arrow
						string = String.fromCharCode(27) + "[1;3A";  // Alt-Up arrow
						break;
					case String.fromCharCode(27) + "[B":  // Down arrow
					case String.fromCharCode(27) + "OB":  // Down arrow
						string = String.fromCharCode(27) + "[1;3B";  // Alt-Down arrow
						break;
					case String.fromCharCode(27) + "[D":  // Left arrow
					case String.fromCharCode(27) + "OD":  // Left arrow
						string = String.fromCharCode(27) + "[1;3D";  // Alt-left arrow
						break;
					case String.fromCharCode(27) + "[C":  // Right arrow
					case String.fromCharCode(27) + "OC":  // Right arrow
						string = String.fromCharCode(27) + "[1;3C";  // Alt-right arrow
						break;
					default:
						// default case: just take the first character and remove 64:
						var charcode = string.toUpperCase().charCodeAt(0);
						string = String.fromCharCode(charcode - 64);
				}
				window.controlOn = false;
				window.webkit.messageHandlers.aShell.postMessage('controlOff');
			}
			// always post keyboard input to TTY:
			window.webkit.messageHandlers.aShell.postMessage('inputTTY:' + string);
			// If help() is running in iPython, then it stops being interactive.
			var helpRunning = false;
			if (window.commandRunning.startsWith("ipython") || window.commandRunning.startsWith("isympy")) {
				var lastNewline = window.printedContent.lastIndexOf("\n");
				var lastLine = window.printedContent.substr(lastNewline + 1); // 1 to skip \n.
				lastLine = lastLine.replace(/(\r\n|\n|\r|\n\r)/gm,""); // skip past \r and \n, if any
				if (lastLine.startsWith("help>")) {
					helpRunning = true;
				} else if (lastLine.includes("Do you really want to exit ([y]/n)?")) {
					helpRunning = true;
				}
			}
			// Easiest way to handle the case where Python (non-interactive) starts help, which starts less, which 
			// changes the status to interactive, but does not reset it when leaving.
			// TODO: adress the larger issue where a non-interactive command starts an interactive command.
			if (window.commandRunning.startsWith("python")) {
				var lastNewline = window.printedContent.lastIndexOf("\n");
				var lastLine = window.printedContent.substr(lastNewline + 1); // 1 to skip \n.
				lastLine = lastLine.replace(/(\r\n|\n|\r|\n\r)/gm,""); // skip past \r and \n, if any
				if ((lastLine.startsWith("help>")) || (lastLine.startsWith(">>>"))) {
					window.interactiveCommandRunning = false;
				}
			}

			if ((window.commandRunning != '') && (term.vt.mouseReport != term.vt.MOUSE_REPORT_DISABLED)) {
				// if an application has enabled mouse report, it is likely to be interactive:
				// (this was added for textual)
				window.webkit.messageHandlers.aShell.postMessage('inputInteractive:' + string);
			} else if (window.interactiveCommandRunning && (window.commandRunning != '') && !helpRunning) {
				// specific treatment for interactive commands: forward all keyboard input to them
				// window.webkit.messageHandlers.aShell.postMessage('sending: ' + string); // for debugging
				// post keyboard input to stdin
				window.webkit.messageHandlers.aShell.postMessage('inputInteractive:' + string);
			} else if ((window.commandRunning != '') && ((string.charCodeAt(0) == 3) || (string.charCodeAt(0) == 4))) {
				// Send control messages back to command:
				// first, flush existing input:
				if (io.currentCommand != '') {
					window.webkit.messageHandlers.aShell.postMessage('input:' + io.currentCommand);
					io.currentCommand = '';
				}
				window.webkit.messageHandlers.aShell.postMessage('input:' + string);
			} else {
				// window.webkit.messageHandlers.aShell.postMessage('Received character: ' + string + ' ' + string.length); // for debugging
				if (io.currentCommand === '') { 
					// new line, reset things: (required for commands inside commands)
					updatePromptPosition();
				}
				var cursorPosition = term.screen_.cursorPosition.column - window.promptEnd;  // remove prompt length
				switch (string) {
					case '\r':
					case '\n':
						if (autocompleteOn) {
							// Autocomplete menu being displayed + press return: select what's visible and remove
							pickCurrentValue();
							break;
						}
						// Before executing command, move to end of line if not already there, and cleanup the line content:
						// Compute how many lines should we move downward:
						var beginCommand = io.currentCommand.slice(0, currentCommandCursorPosition); 
						var lineCursor = Math.floor((lib.wc.strWidth(beginCommand) + window.promptEnd)/ term.screenSize.width);
						var lineEndCommand = Math.floor((lib.wc.strWidth(io.currentCommand) + window.promptEnd)/ term.screenSize.width);
						for (var i = 0; i < lineEndCommand - lineCursor; i++) {
							io.println('');
						}
						io.println('');
						cleanupLastLine();
						if (window.commandRunning != '') {
							// The command takes care of the prompt. Just send the input data:
							window.webkit.messageHandlers.aShell.postMessage('input:' + io.currentCommand + '\n');
							// remove temporarily stored command -- if any
							if (window.maxCommandInsideCommandIndex < window.commandInsideCommandArray.length) {
								window.commandInsideCommandArray.pop();
							}
							// only store non-empty commands:
							// store commands sent:
							if (io.currentCommand.length > 0) {
								if (io.currentCommand != window.commandInsideCommandArray[window.maxCommandInsideCommandIndex - 1]) {
									// only add command to history if it is different from the last one:
									window.maxCommandInsideCommandIndex = window.commandInsideCommandArray.push(io.currentCommand); 
								}
							} 
							while (window.maxCommandInsideCommandIndex >= 100) {
								// We have stored more than 100 commands
								window.commandInsideCommandArray.shift(); // remove first element
								window.maxCommandInsideCommandIndex = window.commandInsideCommandArray.length;
							} 
							window.commandInsideCommandIndex = window.maxCommandInsideCommandIndex; 
						} else {
							if (io.currentCommand.length > 0) {
								// Reinitialize before sending:
								window.commandRunning = io.currentCommand;
								window.interactiveCommandRunning = isInteractive(window.commandRunning);
								// ...and send the command to iOS: 
								window.webkit.messageHandlers.aShell.postMessage('shell:' + io.currentCommand);
								// remove temporarily stored command -- if any
								if (window.maxCommandIndex < window.commandArray.length) {
									window.commandArray.pop();
								}
								if (io.currentCommand != window.commandArray[window.maxCommandIndex - 1]) {
									// only add command to history if it is different from the last one:
									window.maxCommandIndex = window.commandArray.push(window.commandRunning); 
									while (window.maxCommandIndex >= 100) {
										// We have stored more than 100 commands
										window.commandArray.shift(); // remove first element
										window.maxCommandIndex = window.commandArray.length;
									} 
								} 
								window.commandIndex = window.maxCommandIndex; 
								// clear history inside command:
								window.commandInsideCommandArray = [];
								window.commandInsideCommandIndex = 0;
								window.maxCommandInsideCommandIndex = 0;
							} else {
								printPrompt();
								updatePromptPosition(); 
							}
						}
						io.currentCommand = '';
						break;
					case String.fromCharCode(127): // delete key from iOS keyboard
					case String.fromCharCode(8):   // Ctrl+H
						if (currentCommandCursorPosition > 0) { 
							if (this.document_.getSelection().type == 'Range') {
								term.onCut(null); // remove the selection without copying it
							} else {
								deleteBackward();
							}
						}
						disableAutocompleteMenu();
						break;
					case String.fromCharCode(24):  // Ctrl-X
					case String.fromCharCode(26):  // Ctrl-Z // Cancel. Make popup menu disappear
						disableAutocompleteMenu();
						break;
					case String.fromCharCode(27):  // Escape. Make popup menu disappear
						disableAutocompleteMenu();
						break;
					case String.fromCharCode(27) + "[A":  // Up arrow
					case String.fromCharCode(27) + "OA":  // Up arrow
					case String.fromCharCode(27) + "[1;3A":  // Alt-Up arrow
					case String.fromCharCode(16):  // Ctrl+P
						// popup menu being displayed, change it:
						if (autocompleteOn) {
							if (autocompleteIndex > 0) {
								autocompleteIndex -= 1; 
								printAutocompleteString(autocompleteList[autocompleteIndex]);
							}													
							break;
						} else if (window.commandRunning != '') {
							if (window.commandInsideCommandIndex > 0) {
								if (window.commandInsideCommandIndex === window.maxCommandInsideCommandIndex) {
									// Store current command: 
									window.commandInsideCommandArray[window.commandInsideCommandIndex] = io.currentCommand;
								}
								io.print('\x1b[' + (window.promptLine + 1) + ';' + (window.promptEnd + 1) + 'H'); // move cursor back to initial position
								io.print('\x1b[0J'); // delete display after cursor
								if (string != String.fromCharCode(27) + "[1;3A") {
									window.commandInsideCommandIndex -= 1;
									if (window.commandInsideCommandIndex < 0) {
										window.commandInsideCommandIndex = 0;
									}
								} else {
									window.commandInsideCommandIndex -= 5;
									if (window.commandInsideCommandIndex < 0) {
										window.commandInsideCommandIndex = 0;
									}
								}
								io.currentCommand = window.commandInsideCommandArray[window.commandInsideCommandIndex]; 
								io.print(io.currentCommand);
								cleanupLastLine();
								currentCommandCursorPosition = io.currentCommand.length;
							}
						} else {
							if (window.commandIndex > 0) {
								if (window.commandIndex === window.maxCommandIndex) {
									// Store current command: 
									window.commandArray[window.commandIndex] = io.currentCommand;
								}
								var scrolledLines = window.promptScroll - term.scrollPort_.getTopRowIndex();
								io.print('\x1b[' + (window.promptLine + scrolledLines + 1) + ';' + (window.promptEnd + 1) + 'H'); // move cursor to position at start of line
								io.print('\x1b[0J'); // delete display after cursor
								if (string != String.fromCharCode(27) + "[1;3A") {
									window.commandIndex -= 1;
								} else {
									window.commandIndex -= 5;
									if (window.commandIndex < 0) {
										window.commandIndex = 0;
									}
								}
								io.currentCommand = window.commandArray[window.commandIndex]; 
								io.print(io.currentCommand);
								cleanupLastLine();
								currentCommandCursorPosition = io.currentCommand.length;
							} 
						}
						break;
					case String.fromCharCode(27) + "[B":  // Down arrow
					case String.fromCharCode(27) + "OB":  // Down arrow
					case String.fromCharCode(27) + "[1;3B":  // Alt-Down arrow
					case String.fromCharCode(14):  // Ctrl+N
						// popup menu being displayed, change it:
						if (autocompleteOn) {
							if (autocompleteIndex < autocompleteList.length - 1) {
								autocompleteIndex += 1; 
								printAutocompleteString(autocompleteList[autocompleteIndex]);
							}													
							break;
						} else if (window.commandRunning != '') {
							if (window.commandInsideCommandIndex < window.maxCommandInsideCommandIndex) {
								io.print('\x1b[' + (window.promptLine + 1) + ';' + (window.promptEnd + 1) + 'H'); // move cursor to position at start of line
								io.print('\x1b[0J'); // delete display after cursor
								if (string != String.fromCharCode(27) + "[1;3B") {
									window.commandInsideCommandIndex += 1;
								} else {
									window.commandInsideCommandIndex += 5;
									if (window.commandInsideCommandIndex >= window.maxCommandInsideCommandIndex) {
										window.commandInsideCommandIndex = window.maxCommandInsideCommandIndex;
									}
								}
								io.currentCommand = window.commandInsideCommandArray[window.commandInsideCommandIndex]; 
								io.print(io.currentCommand);
								cleanupLastLine();
								currentCommandCursorPosition = io.currentCommand.length;
							} 
						} else {
							if (window.commandIndex < window.maxCommandIndex) {
								var scrolledLines = window.promptScroll - term.scrollPort_.getTopRowIndex();
								io.print('\x1b[' + (window.promptLine + scrolledLines + 1) + ';' + (window.promptEnd + 1) + 'H'); // move cursor to position at start of line
								io.print('\x1b[0J'); // delete display after cursor
								if (string != String.fromCharCode(27) + "[1;3B") {
									window.commandIndex += 1;
								} else {
									window.commandIndex += 5;
									if (window.commandIndex >= window.maxCommandIndex) {
										window.commandIndex = window.maxCommandIndex;
									}
								}
								io.currentCommand = window.commandArray[window.commandIndex]; 
								io.print(io.currentCommand);
								cleanupLastLine();
								currentCommandCursorPosition = io.currentCommand.length;
							}
						}
						break;
					case String.fromCharCode(27) + "[D":  // Left arrow
					case String.fromCharCode(27) + "OD":  // Left arrow
					case String.fromCharCode(2):  // Ctrl+B
						if (this.document_.getSelection().type == 'Range') {
							// move cursor to start of selection
							this.moveCursorPosition(term.scrollPort_.selection.startRow.rowIndex - term.scrollPort_.getTopRowIndex(), term.scrollPort_.selection.startOffset);
							this.document_.getSelection().collapseToStart();
							disableAutocompleteMenu();
						} else {
							if (currentCommandCursorPosition > 0) { 
								var previousCursorPosition = 0;
								var currentChar;
								for (const v of window.term_.io.currentCommand) {
									if (previousCursorPosition + v.length >= currentCommandCursorPosition) {
										currentChar = v;
										break;
									}
									previousCursorPosition += v.length;
								}
								var currentCharWidth = lib.wc.strWidth(currentChar);
								this.document_.getSelection().empty();
								for (var i = 0; i < currentCharWidth; i++) {
									io.print('\b'); // move cursor back n chars, across lines
								}
								currentCommandCursorPosition = previousCursorPosition;
							}
						}
						break;
					case String.fromCharCode(27) + "[C":  // Right arrow
					case String.fromCharCode(27) + "OC":  // Right arrow
					case String.fromCharCode(6):  // Ctrl+F
						if (this.document_.getSelection().type == 'Range') {
							// move cursor to end of selection
							this.moveCursorPosition(term.scrollPort_.selection.endRow.rowIndex - term.scrollPort_.getTopRowIndex(), term.scrollPort_.selection.endOffset);
							this.document_.getSelection().collapseToEnd();
							disableAutocompleteMenu();
						} else if (autocompleteOn) {
							// hit right arrow when autocomplete menu already visible = select current
							pickCurrentValue();
						} else {
							if (currentCommandCursorPosition < io.currentCommand.length) {
								const codePoint = io.currentCommand.codePointAt(currentCommandCursorPosition);
								var currentChar = String.fromCodePoint(codePoint);
								var	currentCharWidth = lib.wc.strWidth(currentChar);
								var nextCodePointPosition = currentCommandCursorPosition + 1;
								if (codePoint >= 0x010000) {
								    nextCodePointPosition += 1;
								}
								while (nextCodePointPosition < io.currentCommand.length) {
									const nextCodePoint = io.currentCommand.codePointAt(nextCodePointPosition);
									const nextChar = String.fromCodePoint(nextCodePoint);
									const isModifier = (nextChar.match(/\p{Emoji_Modifier}/gu) != null);
									if (isModifier) {
										// advance over modifier:
										nextCodePointPosition += 1;
										currentCharWidth += nextChar.length;
										if (nextCodePoint >= 0x010000) {
											nextCodePointPosition += 1;
										}
									} else if (nextCodePoint == 8205) {
										// zero-width joiner, move forward and keep joining
										nextCodePointPosition += 1;
										if (nextCodePoint >= 0x010000) {
											nextCodePointPosition += 1;
										}
										currentCharWidth += nextChar.length;
										if (nextCodePointPosition < io.currentCommand.length) {
											// Advance over the next character:
											const nextCodePoint = io.currentCommand.codePointAt(nextCodePointPosition);
											nextCodePointPosition += 1; 
											if (nextCodePoint >= 0x010000) {
												nextCodePointPosition += 1;
											}
											currentCharWidth += nextChar.length;
											// Can I have a modifier in the middle of a joined-emoji?
										}
									} else {
										break;
									}
								}
								if (term.screen_.cursorPosition.column < term.screenSize.width - currentCharWidth) {
									io.print('\x1b[' + currentCharWidth + 'C'); // move cursor forward n chars
								} else {
									io.print('\x1b[' + (term.screen_.cursorPosition.row + 2) + ';' + 0 + 'H'); // move cursor to start of next line
								}
								currentCommandCursorPosition = nextCodePointPosition;
								this.document_.getSelection().empty();
							}
						}
						break; 
					case String.fromCharCode(27) + "[1;3D":  // Alt-left arrow
						disableAutocompleteMenu();
						if (currentCommandCursorPosition > 0) { // prompt.length
							while (currentCommandCursorPosition > 0) {
								// get previous char, emoji compatible
								var previousCursorPosition = 0;
								var currentChar;
								for (const v of window.term_.io.currentCommand) {
									if (previousCursorPosition + v.length >= currentCommandCursorPosition) {
										currentChar = v;
										break;
									}
									previousCursorPosition += v.length;
								}
								var currentCharWidth = lib.wc.strWidth(currentChar);
								currentCommandCursorPosition = previousCursorPosition;
								for (var i = 0; i < currentCharWidth; i++) {
									io.print('\b'); // move cursor back n chars, across lines
								}
								if  (!isLetter(currentChar)) {
									break;
								}
							}
						}
						break;
					case String.fromCharCode(27) + "[1;3C":  // Alt-right arrow
						disableAutocompleteMenu();
						if (currentCommandCursorPosition < io.currentCommand.length) { // prompt.length
							while (currentCommandCursorPosition < io.currentCommand.length) {
								const codePoint = io.currentCommand.codePointAt(currentCommandCursorPosition);
								var currentChar = String.fromCodePoint(codePoint);
								var currentCharWidth = lib.wc.strWidth(currentChar);
								var nextCodePointPosition = currentCommandCursorPosition + 1;
								if (codePoint >= 0x010000) {
								    nextCodePointPosition += 1;
								}
								// Move forward until the end of the current emoji (copied from right-arrow):
								while (nextCodePointPosition < io.currentCommand.length) {
									const nextCodePoint = io.currentCommand.codePointAt(nextCodePointPosition);
									const nextChar = String.fromCodePoint(nextCodePoint);
									const isModifier = (nextChar.match(/\p{Emoji_Modifier}/gu) != null);
									if (isModifier) {
										// advance over modifier:
										nextCodePointPosition += 1;
										currentCharWidth += nextChar.length;
										if (nextCodePoint >= 0x010000) {
											nextCodePointPosition += 1;
										}
									} else if (nextCodePoint == 8205) {
										// zero-width joiner, move forward and keep joining
										nextCodePointPosition += 1;
										if (nextCodePoint >= 0x010000) {
											nextCodePointPosition += 1;
										}
										currentCharWidth += nextChar.length;
										if (nextCodePointPosition < io.currentCommand.length) {
											// Advance over the next character:
											const nextCodePoint = io.currentCommand.codePointAt(nextCodePointPosition);
											nextCodePointPosition += 1; 
											if (nextCodePoint >= 0x010000) {
												nextCodePointPosition += 1;
											}
											currentCharWidth += nextChar.length;
											// Can I have a modifier in the middle of a joined-emoji?
										}
									} else {
										break;
									}
								}
								if (term.screen_.cursorPosition.column < term.screenSize.width - currentCharWidth) {
									io.print('\x1b[' + currentCharWidth + 'C'); // move cursor forward n chars
								} else {
									io.print('\x1b[' + (term.screen_.cursorPosition.row + 2) + ';' + 0 + 'H'); // move cursor to start of next line
								}
								currentCommandCursorPosition = nextCodePointPosition;
								if  (!isLetter(currentChar)) {
									break;
								}
							}
						}
						break;
					case String.fromCharCode(9):  // Tab, so autocomplete
						if ((window.commandRunning == '') ||
							window.commandRunning.startsWith('dash') || window.commandRunning.startsWith('sh')) {
							if (autocompleteOn) {
								// hit tab when menu already visible = select current
								pickCurrentValue();
							} else {
								// Work on autocomplete list / current command
								updateAutocompleteMenu(io, currentCommandCursorPosition); 
							}
						} else {
							// no autocomplete inside running commands. Just print 4 spaces.
							// (spaces because tab confuse hterm)
							io.currentCommand = io.currentCommand.slice(0, currentCommandCursorPosition) + "    " + 
								io.currentCommand.slice(currentCommandCursorPosition, io.currentCommand.length);
							printString("    ");
							currentCommandCursorPosition += 4;
						}
						break;
					case String.fromCharCode(1):  // Ctrl-A: beginnging of line
						disableAutocompleteMenu();
						if (currentCommandCursorPosition > 0) { // prompt.length
							var scrolledLines = window.promptScroll - this.scrollPort_.getTopRowIndex();
							var topRowCommand = window.promptLine + scrolledLines;
							this.io.print('\x1b[' + (topRowCommand + 1) + ';' + (window.promptEnd + 1) + 'H'); // move cursor to new position 
							currentCommandCursorPosition = 0; 
						}
						break;
					case String.fromCharCode(3):  // Ctrl-C: cancel current command
						disableAutocompleteMenu();
						// Before *not*-executing command, move to end of line if not already there:
						// Compute how many lines should we move downward:
						if (io.currentCommand == '') {
							break;
						}
						var beginCommand = io.currentCommand.slice(0, currentCommandCursorPosition); 
						var lineCursor = Math.floor((lib.wc.strWidth(beginCommand) + window.promptEnd)/ term.screenSize.width);
						var lineEndCommand = Math.floor((lib.wc.strWidth(io.currentCommand) + window.promptEnd)/ term.screenSize.width);
						for (var i = 0; i < lineEndCommand - lineCursor; i++) {
							io.println('');
						}
						io.println('');
						printPrompt();
						updatePromptPosition(); 
						io.currentCommand = '';
						currentCommandCursorPosition = 0;
						if (window.commandRunning != '') {
							window.commandInsideCommandIndex = window.maxCommandInsideCommandIndex; 
						} else { 									
							window.commandIndex = window.maxCommandIndex
						}
						break;
					case String.fromCharCode(27) + "[3~":  // Delete key
					case String.fromCharCode(4):  // Ctrl-D: delete character after cursor
						disableAutocompleteMenu();
						if (currentCommandCursorPosition < io.currentCommand.length) {
							var currentChar = io.currentCommand[currentCommandCursorPosition];
							var currentCharWidth = lib.wc.strWidth(currentChar);
							io.print('\x1b[0J'); // delete display after cursor
							// print remainder of command line
							var endOfCommand = io.currentCommand.slice(currentCommandCursorPosition + 1, io.currentCommand.length);
							io.print(endOfCommand)
							// move cursor back to where it was (don't use term.screen_.cursorPosition):
							var wcwidth = lib.wc.strWidth(endOfCommand);
							for (var i = 0; i < wcwidth; i++) {
								io.print('\b'); 
							}
							// remove character from command at current position:
							io.currentCommand = io.currentCommand.slice(0, currentCommandCursorPosition) + 
								io.currentCommand.slice(currentCommandCursorPosition + 1, io.currentCommand.length); 
						}
						break;
					case String.fromCharCode(5):  // Ctrl-E: end of line
						disableAutocompleteMenu();
						if (currentCommandCursorPosition < io.currentCommand.length) {
							var scrolledLines = window.promptScroll - this.scrollPort_.getTopRowIndex();
							var topRowCommand = window.promptLine + scrolledLines;
							var fullLength = lib.wc.strWidth(io.currentCommand) + window.promptEnd; 
							var y = Math.floor((fullLength / this.screenSize.width)) ;
							var x = fullLength - this.screenSize.width * y;
							y += topRowCommand

							this.io.print('\x1b[' + (y + 1) + ';' + (x + 1) + 'H'); // move cursor to new position 
							currentCommandCursorPosition = io.currentCommand.length; 
						}
						break;
					case String.fromCharCode(11):  // Ctrl-K: kill until end of line
						disableAutocompleteMenu();
						if (currentCommandCursorPosition < io.currentCommand.length) { 
							io.currentCommand = io.currentCommand.slice(0, currentCommandCursorPosition)
							window.term_.io.print('\x1b[0J'); // delete display after cursor
						}
						break;
					case String.fromCharCode(21):  // Ctrl-U: kill from cursor to beginning of the line
						disableAutocompleteMenu();
						if (currentCommandCursorPosition > 0) { // prompt.length
							// move cursor back to beginning of the line
							const scrolledLines = window.promptScroll - this.scrollPort_.getTopRowIndex();
							const topRowCommand = window.promptLine + scrolledLines;
							io.print('\x1b[' + (topRowCommand + 1) + ';0H');
							// clear cursor to end of display
							io.print('\x1b[0J');
							// backup remaining characters
							const remaining = io.currentCommand.slice(currentCommandCursorPosition);
							// redraw prompt
							printPrompt();  // This erases the entire io.currentCommand
							updatePromptPosition();
							// restore and draw remaining characters
							io.currentCommand = remaining
							io.print(io.currentCommand);
							// move cursor back to beginning of the line
							io.print(`\x1b[${window.promptEnd + 1}G`);
							currentCommandCursorPosition = 0;
						}
						break;
					case String.fromCharCode(27) + String.fromCharCode(127):  // Alt-delete key from iOS keyboard: kill the word behind point
						disableAutocompleteMenu();
						deleteBackward();
						while (currentCommandCursorPosition > 0) {
							const currentChar = io.currentCommand[currentCommandCursorPosition - 1];
							if (!isLetter(currentChar)) {
								break;
							}
							deleteBackward();
						}
						break;
					case String.fromCharCode(23):  // Ctrl+W: kill the word behind point, using white space as a word boundary
						disableAutocompleteMenu();
						deleteBackward();
						while (currentCommandCursorPosition > 0) {
							const currentChar = io.currentCommand[currentCommandCursorPosition - 1];
							if (currentChar === ' ') {
								break;
							}
							deleteBackward();
						}
						break;
					case String.fromCharCode(12):  // Ctrl-L: clear screen
						disableAutocompleteMenu();
						// erase display, move cursor to (1,1)
						window.term_.io.print('\x1b[2J\x1b[1;1H');
						// redraw command:
						printPrompt();
						window.term_.io.print(io.currentCommand);
						var endOfCommand = io.currentCommand.slice(currentCommandCursorPosition, io.currentCommand.length);
						// move cursor back to where it was (don't use term.screen_.cursorPosition):
						var wcwidth = lib.wc.strWidth(endOfCommand);
						for (var i = 0; i < wcwidth; i++) {
							io.print('\b'); 
						}
						break;
					case String.fromCharCode(32): // Space: end auto-complete
						disableAutocompleteMenu(); 
					default:
						// window.webkit.messageHandlers.aShell.postMessage('onVTKeyStroke received ' + string);
						// insert character at cursor position:
						if (this.document_.getSelection().type == 'Range') {
							term.onCut(null); // remove the selection without copying it
						}
						this.document_.getSelection().empty(); 
						// Remove all escape characters if we reach this point:
						// Also remove '\r' and ^D characters (when pasting):
						var newString = string.replaceAll(String.fromCharCode(27), '').replaceAll(String.fromCharCode(13), '').replaceAll(String.fromCharCode(4), '');
						// For debugging:
						// for (var i = 0; i < newString.length; i++) {
						// 	var charcode = newString.charCodeAt(i);
						// 	window.webkit.messageHandlers.aShell.postMessage("char " + i + " = " + charcode + " = " + newString[i]);
						// }
						printString(newString);  // print before we update io.currentCommand
						io.currentCommand = io.currentCommand.slice(0, currentCommandCursorPosition) + newString + 
							io.currentCommand.slice(currentCommandCursorPosition, io.currentCommand.length);
						currentCommandCursorPosition += newString.length;
						if (autocompleteOn) {
							updateAutocompleteMenu(io, currentCommandCursorPosition); 
						}
						break;
				}
			}
		};
		term.moveCursorPosition = function(y, x) {
			// If currentCommand is empty, update prompt position (JS is asynchronous, position might have been computed before the end of the scroll)
			if (io.currentCommand === '') {
				updatePromptPosition();
			}
			var scrolledLines = window.promptScroll - this.scrollPort_.getTopRowIndex();
			var topRowCommand = window.promptLine + scrolledLines;
			// Don't move cursor outside of current line
			if (y < topRowCommand) { 
				return; 
			}
			// this.screen_.setCursorPosition(y, x);  // does not update blinking cursor position
			if (x < window.promptEnd) {
				return; 
				// x = window.promptEnd;
			}
			var deltay = this.screen_.cursorPosition.row - y;
			var deltax = this.screen_.cursorPosition.column - x;
			var deltaCursor = deltax + deltay * this.screenSize.width; // by how many *characters* should we move?
			if (currentCommandCursorPosition - deltaCursor > lib.wc.strWidth(io.currentCommand)) {
				// If we are after the end of the line, move to the end of the line.
				var overclick = currentCommandCursorPosition - deltaCursor - lib.wc.strWidth(io.currentCommand);
				deltaCursor += overclick;
				// At the end of the line, so move there.
				var fullLength = lib.wc.strWidth(io.currentCommand) + window.promptEnd; 
				var y = Math.floor((fullLength / this.screenSize.width)) ;
				var x = fullLength - this.screenSize.width * y;
				y += topRowCommand
			}
			// Now compute the new position inside the command line, taking into account multi-byte characters.
			// We assume characters have a width of at least 1, so we move of at least deltaCursor.
			var newCursorPosition = currentCommandCursorPosition; // - deltaCursor; 
			if (deltaCursor > 0) {
				// deltaCursor is computed in screen char width. cursorPosition is computed in char inside the string.
				// We move back by -deltaCursor characters.
				var endOfStringPosition = 0;
				var currentChar;
				var string = ''
				for (const v of window.term_.io.currentCommand) {
					string = io.currentCommand.slice(endOfStringPosition, currentCommandCursorPosition);
					if (lib.wc.strWidth(string) <= deltaCursor) {
						break;
					}
					endOfStringPosition += v.length;
				}
				newCursorPosition = endOfStringPosition;
			} else {
				// We move forward by deltaCursor characters:
				var string = '';
				var endOfStringPosition = 0;
				while (lib.wc.strWidth(string) < -deltaCursor) {
					const codePoint = io.currentCommand.codePointAt(newCursorPosition);
					var currentChar = String.fromCodePoint(codePoint);
					string += currentChar;
					newCursorPosition += 1; 
					if (codePoint >= 0x010000) {
						newCursorPosition += 1;
					}
				}
			}
			currentCommandCursorPosition = newCursorPosition;
			io.print('\x1b[' + (y + 1) + ';' + (x + 1) + 'H'); // move cursor to new position 
		};
		io.sendString = io.onVTKeystroke; // was io.print
		initContent(io);
		// Store currentCommand in term.io:
		io.currentCommand = '';
		this.setCursorVisible(true);
		this.setCursorBlink(false);
		this.setFontSize(window.fontSize); 
		this.setFontFamily(window.fontFamily); 
		this.setForegroundColor(window.foregroundColor);
		this.setBackgroundColor(window.backgroundColor);
		this.setCursorColor(window.cursorColor);
		this.setCursorShape(window.cursorShape);
		this.keyboard.characterEncoding = 'raw';
		// this.keyboard.bindings.addBinding('F11', 'PASS');
		// this.keyboard.bindings.addBinding('Ctrl-R', 'PASS');
	};
	term.decorate(document.querySelector('#terminal'));
	term.installKeyboard();
	window.term_ = term;
	// Useful for console debugging. But it causes some errors in hterm_all
	// console.log = println
	// console.warn = window.webkit.messageHandlers.aShell.postMessage
	// console.error = window.webkit.messageHandlers.aShell.postMessage
	if (window.foregroundColor === undefined) {
		window.webkit.messageHandlers.aShell.postMessage('resendConfiguration:');
	}
	if (window.commandRunning === undefined) {
		window.commandRunning = '';
	}
	window.interactiveCommandRunning = isInteractive(window.commandRunning);
	if (window.commandArray === undefined) {
		window.commandArray = new Array();
		window.commandIndex = 0;
		window.maxCommandIndex = 0;
	}
	window.commandInsideCommandArray = new Array();
	window.commandInsideCommandIndex = 0;
	window.maxCommandInsideCommandIndex = 0;
	if (window.promptMessage === undefined) {
		window.promptMessage = "$ ";
	}
	window.promptEnd = 2; // prompt for commands, configurable
	window.promptLine = 0; // term line on which the prompt started
	window.promptScroll = 0; // scroll line on which the scrollPort was when the prompt started
	if (window.voiceOver != undefined) {
		window.term_.setAccessibilityEnabled(window.voiceOver);
	}
	// if (window.printedContent === undefined) {
	// 	window.printedContent = '';
	// }
	window.duringResize = false;
	// If a command was started while we were starting the terminal, we might not know about it:
	// This also prints the first prompt, after updating the prompt message.
	window.webkit.messageHandlers.aShell.postMessage('resendCommand:');
	initializeTerminalGestures();
};

// see https://github.com/holzschu/a-shell/issues/235
// This will be whatever normal entry/initialization point your project uses.
window.onload = async function() {
	await lib.init();
	setupHterm();
};

// Modifications and additions to hterm_all.js:
hterm.Terminal.IO.prototype.onTerminalResize = function(width, height) {
  window.webkit.messageHandlers.aShell.postMessage('width:'  + width); 
  window.webkit.messageHandlers.aShell.postMessage('height:'  + height); 
};

hterm.Frame.prototype.postMessage = function(name, argv) {
  window.webkit.messageHandlers.aShell.postMessage('JS Error:' + name + ' argv= ' + argv); 
  if (this.messageChannel_) {
	  this.messageChannel_.port1.postMessage({name: name, argv: argv});
  }
};

/**
 * Handle keydown events.
 *
 * @param {!KeyboardEvent} e The event to process.
 */
hterm.Keyboard.prototype.onKeyDown_ = function(e) {
  if (e.keyCode == 18) {
    this.altKeyPressed = this.altKeyPressed | (1 << (e.location - 1));
  }

  if (e.keyCode == 27) {
    this.preventChromeAppNonCtrlShiftDefault_(e);
  }

  let keyDef = this.keyMap.keyDefs[e.keyCode];
  if (!keyDef) {
    // If this key hasn't been explicitly registered, fall back to the unknown
    // key mapping (keyCode == 0), and then automatically register it to avoid
    // any further warnings here.
    console.warn(`No definition for key ${e.key} (keyCode ${e.keyCode})`);
    keyDef = this.keyMap.keyDefs[0];
    this.keyMap.addKeyDef(e.keyCode, keyDef);
  }

  // The type of action we're going to use.
  let resolvedActionType = null;

  /**
   * @param {string} name
   * @return {!hterm.Keyboard.KeyDefAction}
   */
  const getAction = (name) => {
    // Get the key action for the given action name.  If the action is a
    // function, dispatch it.  If the action defers to the normal action,
    // resolve that instead.

    resolvedActionType = name;

    let action = keyDef[name];
    if (typeof action == 'function') {
      action = action.call(this.keyMap, e, keyDef);
    }

    if (action === DEFAULT && name != 'normal') {
      action = getAction('normal');
    }

    return action;
  };

  // Note that we use the triple-equals ('===') operator to test equality for
  // these constants, in order to distinguish usage of the constant from usage
  // of a literal string that happens to contain the same bytes.
  const CANCEL = hterm.Keyboard.KeyActions.CANCEL;
  const DEFAULT = hterm.Keyboard.KeyActions.DEFAULT;
  const PASS = hterm.Keyboard.KeyActions.PASS;
  const STRIP = hterm.Keyboard.KeyActions.STRIP;

  let control = e.ctrlKey;
  let alt = this.altIsMeta ? false : e.altKey;
  let meta = this.altIsMeta ? (e.altKey || e.metaKey) : e.metaKey;

  // In the key-map, we surround the keyCap for non-printables in "[...]"
  const isPrintable = !(/^\[\w+\]$/.test(keyDef.keyCap));

  // iOS: we copied the entire onKeyDown function just so that we could have both left-alt and right-alt as altGr:
  if (isPrintable && (this.terminal.keyboard.altKeyPressed > 0)) {
  	  control = false;
  	  alt = false;
  }
/* old version:
  switch (this.altGrMode) {
    case 'ctrl-alt':
    if (isPrintable && control && alt) {
      // ctrl-alt-printable means altGr.  We clear out the control and
      // alt modifiers and wait to see the charCode in the keydown event.
      control = false;
      alt = false;
    }
    break;

    case 'right-alt':
    if (isPrintable && (this.terminal.keyboard.altKeyPressed & 2)) {
      control = false;
      alt = false;
    }
    break;

    case 'left-alt':
    if (isPrintable && (this.terminal.keyboard.altKeyPressed & 1)) {
      control = false;
      alt = false;
    }
    break;
  } */

  /** @type {?hterm.Keyboard.KeyDefAction} */
  let action;

  if (control) {
    action = getAction('control');
  } else if (alt) {
    action = getAction('alt');
  } else if (meta) {
    action = getAction('meta');
  } else {
    action = getAction('normal');
  }

  // If e.maskShiftKey was set (during getAction) it means the shift key is
  // already accounted for in the action, and we should not act on it any
  // further. This is currently only used for Ctrl+Shift+Tab, which should send
  // "CSI Z", not "CSI 1 ; 2 Z".
  let shift = !e.maskShiftKey && e.shiftKey;

  /** @type {!hterm.Keyboard.KeyDown} */
  const keyDown = {
    keyCode: e.keyCode,
    shift: e.shiftKey, // not `var shift` from above.
    ctrl: control,
    alt: alt,
    meta: meta,
  };

  const binding = this.bindings.getBinding(keyDown);

  if (binding) {
    // Clear out the modifier bits so we don't try to munge the sequence
    // further.
    shift = control = alt = meta = false;
    resolvedActionType = 'normal';

    if (typeof binding.action == 'function') {
      const bindingFn =
          /** @type {!hterm.Keyboard.KeyBindingFunction} */ (binding.action);
      action = bindingFn.call(this, this.terminal, keyDown);
    } else {
      action = /** @type {!hterm.Keyboard.KeyAction} */ (binding.action);
    }
  }

  // Call keyDef function now that we have given bindings a chance to override.
  if (typeof action == 'function') {
    action = action.call(this.keyMap, e, keyDef);
  }

  if (alt && this.altSendsWhat == 'browser-key' && action == DEFAULT) {
    // When altSendsWhat is 'browser-key', we wait for the keypress event.
    // In keypress, the browser should have set the event.charCode to the
    // appropriate character.
    // TODO(rginda): Character compositions will need some black magic.
    action = PASS;
  }

  // If we are going to handle the key, we most likely want to hide the context
  // menu before doing so.  This way we hide it when pressing a printable key,
  // or navigate (arrow keys/etc...), or press Escape.  But we don't want to
  // hide it when only pressing modifiers like Alt/Ctrl/Meta because those might
  // be used by the OS & hterm to show the context menu in the first place.  The
  // bare modifier keys are all marked as PASS.
  if (action !== PASS) {
    this.terminal.contextMenu.hide();
  }

  if (action === PASS || (action === DEFAULT && !(control || alt || meta))) {
    // If this key is supposed to be handled by the browser, or it is an
    // unmodified key with the default action, then exit this event handler.
    // If it's an unmodified key, it'll be handled in onKeyPress where we
    // can tell for sure which ASCII code to insert.
    //
    // This block needs to come before the STRIP test, otherwise we'll strip
    // the modifier and think it's ok to let the browser handle the keypress.
    // The browser won't know we're trying to ignore the modifiers and might
    // perform some default action.
    return;
  }

  if (action === STRIP) {
    alt = control = false;
    action = keyDef.normal;
    if (typeof action == 'function') {
      action = action.call(this.keyMap, e, keyDef);
    }

    if (action == DEFAULT && keyDef.keyCap.length == 2) {
      action = keyDef.keyCap.substr((shift ? 1 : 0), 1);
    }
  }

  e.preventDefault();
  e.stopPropagation();

  if (action === CANCEL) {
    return;
  }

  if (action !== DEFAULT && typeof action != 'string') {
    console.warn('Invalid action: ' + JSON.stringify(action));
    return;
  }

  // Strip the modifier that is associated with the action, since we assume that
  // modifier has already been accounted for in the action.
  if (resolvedActionType == 'control') {
    control = false;
  } else if (resolvedActionType == 'alt') {
    alt = false;
  } else if (resolvedActionType == 'meta') {
    meta = false;
  }

	
  if (typeof action == 'string' && action.substr(0, 2) == '\x1b[' &&
      (alt || control || shift || meta)) {
    // The action is an escape sequence that and it was triggered in the
    // presence of a keyboard modifier, we may need to alter the action to
    // include the modifier before sending it.

    // The math is funky but aligns w/xterm.
    let imod = 1;
    if (shift) {
      imod += 1;
    }
    if (alt) {
      imod += 2;
    }
    if (control) {
      imod += 4;
    }
    if (meta) {
      imod += 8;
    }
    const mod = ';' + imod;

    if (action.length == 3) {
      // Some of the CSI sequences have zero parameters unless modified.
      action = '\x1b[1' + mod + action.substr(2, 1);
    } else {
      // Others always have at least one parameter.
      action = action.substr(0, action.length - 1) + mod +
          action.substr(action.length - 1);
    }

  } else {
    if (action === DEFAULT) {
      action = keyDef.keyCap.substr((shift ? 1 : 0), 1);

      if (control) {
        const unshifted = keyDef.keyCap.substr(0, 1);
        const code = unshifted.charCodeAt(0);
        if (code >= 64 && code <= 95) {
          action = String.fromCharCode(code - 64);
        }
      }
    }

    if (alt && this.altSendsWhat == '8-bit' && action.length == 1) {
      const code = action.charCodeAt(0) + 128;
      action = String.fromCharCode(code);
    }

    // We respect alt/metaSendsEscape even if the keymap action was a literal
    // string.  Otherwise, every overridden alt/meta action would have to
    // check alt/metaSendsEscape.
    if ((alt && this.altSendsWhat == 'escape') ||
        (meta && this.metaSendsEscape)) {
      action = '\x1b' + action;
    }
  }

  this.terminal.onVTKeystroke(/** @type {string} */ (action));
};

/**
 * React when the ScrollPort is resized.
 *
 * Note: This function should not directly contain code that alters the internal
 * state of the terminal.  That kind of code belongs in realizeWidth or
 * realizeHeight, so that it can be executed synchronously in the case of a
 * programmatic width change.
 */
hterm.Terminal.prototype.onResize_ = function() {
  // window.webkit.messageHandlers.aShell.postMessage('onResize_ terminal event: ' + this.scrollPort_.getScreenWidth() + ' x ' + this.scrollPort_.getScreenHeight());
  // window.webkit.messageHandlers.aShell.postMessage('columnCount: ' + this.scrollPort_.getScreenWidth() / this.scrollPort_.characterSize.width);
  const columnCount = Math.floor(this.scrollPort_.getScreenWidth() /
                                 this.scrollPort_.characterSize.width) || 0;
  const rowCount = lib.f.smartFloorDivide(
      this.scrollPort_.getScreenHeight(),
      this.scrollPort_.characterSize.height) || 0;

  if (columnCount <= 0 || rowCount <= 0) {
    // We avoid these situations since they happen sometimes when the terminal
    // gets removed from the document or during the initial load, and we can't
    // deal with that.
    // This can also happen if called before the scrollPort calculates the
    // character size, meaning we dived by 0 above and default to 0 values.
    return;
  }

  const isNewSize = (columnCount != this.screenSize.width ||
                     rowCount != this.screenSize.height);
  const wasScrolledEnd = this.scrollPort_.isScrolledEnd;

  // We do this even if the size didn't change, just to be sure everything is
  // in sync.
  this.realizeSize_(columnCount, rowCount);
  // iOS addition: set left margin to 50% of remainder of pixels (instead of all on the right)
  let margin = (this.scrollPort_.getScreenWidth() - columnCount * this.scrollPort_.characterSize.width) / 2;
  this.div_.style.marginLeft = Math.round(margin)+'px';

  // this.updateCssCharsize_(); // but why?

  if (isNewSize) {
    this.overlaySize();
  }

  this.restyleCursor_();
  this.scheduleSyncCursorPosition_();

  if (wasScrolledEnd) {
    this.scrollEnd();
  }
};

/**
 * Synchronizes the visible cursor and document selection with the current
 * cursor coordinates.
 *
 * @return {boolean} True if the cursor is onscreen and synced.
 */
hterm.Terminal.prototype.syncCursorPosition_ = function() {
  const topRowIndex = this.scrollPort_.getTopRowIndex();
  const bottomRowIndex = this.scrollPort_.getBottomRowIndex(topRowIndex);
  const cursorRowIndex = this.scrollbackRows_.length +
      this.screen_.cursorPosition.row;

  let forceSyncSelection = false;
  if (this.accessibilityReader_.accessibilityEnabled) {
    // Report the new position of the cursor for accessibility purposes.
    const cursorColumnIndex = this.screen_.cursorPosition.column;
    const cursorLineText =
        this.screen_.rowsArray[this.screen_.cursorPosition.row].innerText;
    // This will force the selection to be sync'd to the cursor position if the
    // user has pressed a key. Generally we would only sync the cursor position
    // when selection is collapsed so that if the user has selected something
    // we don't clear the selection by moving the selection. However when a
    // screen reader is used, it's intuitive for entering a key to move the
    // selection to the cursor.
    forceSyncSelection = this.accessibilityReader_.hasUserGesture;
    this.accessibilityReader_.afterCursorChange(
        cursorLineText, cursorRowIndex, cursorColumnIndex);
  }

  if (cursorRowIndex > bottomRowIndex) {
    // Cursor is scrolled off screen, hide it.
    this.cursorOffScreen_ = true;
    this.cursorNode_.style.display = 'none';
    return false;
  }

  if (this.cursorNode_.style.display == 'none') {
    // Re-display the terminal cursor if it was hidden.
    this.cursorOffScreen_ = false;
    this.cursorNode_.style.display = '';
  }

  // Position the cursor using CSS variable math.  If we do the math in JS,
  // the float math will end up being more precise than the CSS which will
  // cause the cursor tracking to be off.
  this.setCssVar(
      'cursor-offset-row',
      `${cursorRowIndex - topRowIndex} + ` +
      `${this.scrollPort_.visibleRowTopMargin}px`);
    
	// screen_.cursorPosition.column = the position of the current char in the string. It's not equal to the cursor position when there are emojis, so we recompute each time:
	// Sometimes, substr is empty. So we just compute the delta (by how much we should move *back*)
	let substr = lib.wc.substr(this.screen_.rowsArray[this.screen_.cursorPosition.row].innerText, 0, this.screen_.cursorPosition.column);
	let delta = substr.length - screenWidth(substr);
	let actualCursorPosition =   this.screen_.cursorPosition.column - delta;
	this.setCssVar('cursor-offset-col', actualCursorPosition);

	this.cursorNode_.setAttribute('title',
		'(' + actualCursorPosition +
		', ' + this.screen_.cursorPosition.row +
		')');

  // Update the caret for a11y purposes unless FindBar has focus which it should
  // keep.
  if (!this.findBar.hasFocus) {
    const selection = this.document_.getSelection();
    if (selection && (selection.isCollapsed || forceSyncSelection)) {
      this.screen_.syncSelectionCaret(selection);
    }
  }
  return true;
};

/**
 * Initialises the content of this.iframe_. This needs to be done asynchronously
 * in FF after the Iframe's load event has fired.
 *
 * @private
 */
// iOS: that's one big function to copy for one small change. Would be nice to reduce it.
hterm.ScrollPort.prototype.paintIframeContents_ = function() {
  this.iframe_.contentWindow.addEventListener('resize',
                                              this.onResize_.bind(this));

  const doc = this.document_ = this.iframe_.contentDocument;
  doc.body.style.cssText = (
      'margin: 0px;' +
      'padding: 0px;' +
      'height: 100%;' +
      'width: 100%;' +
      'overflow: hidden;' +
      'cursor: var(--hterm-mouse-cursor-style);' +
      'user-select: none;');

  const metaCharset = doc.createElement('meta');
  metaCharset.setAttribute('charset', 'utf-8');
  doc.head.appendChild(metaCharset);

  if (this.DEBUG_) {
    // When we're debugging we add padding to the body so that the offscreen
    // elements are visible.
    this.document_.body.style.paddingTop =
        this.document_.body.style.paddingBottom =
        'calc(var(--hterm-charsize-height) * 3)';
  }

  const style = doc.createElement('style');
  style.textContent = (
      'x-row {' +
      '  display: block;' +
      '  height: var(--hterm-charsize-height);' +
      '  line-height: var(--hterm-charsize-height);' +
      '}');
  doc.head.appendChild(style);

  this.userCssLink_ = doc.createElement('link');
  this.userCssLink_.setAttribute('rel', 'stylesheet');

  this.userCssText_ = doc.createElement('style');
  doc.head.appendChild(this.userCssText_);

  // TODO(rginda): Sorry, this 'screen_' isn't the same thing as hterm.Screen
  // from screen.js.  I need to pick a better name for one of them to avoid
  // the collision.
  // We make this field editable even though we don't actually allow anything
  // to be edited here so that Chrome will do the right thing with virtual
  // keyboards and IMEs.  But make sure we turn off all the input helper logic
  // that doesn't make sense here, and might inadvertently mung or save input.
  // Some of these attributes are standard while others are browser specific,
  // but should be safely ignored by other browsers.
  this.screen_ = doc.createElement('x-screen');
  this.screen_.setAttribute('contenteditable', 'true');
  this.screen_.setAttribute('spellcheck', 'false');
  this.screen_.setAttribute('autocomplete', 'off');
  this.screen_.setAttribute('autocorrect', 'off');
  this.screen_.setAttribute('autocapitalize', 'none');

  // In some ways the terminal behaves like a text box but not in all ways. It
  // is not editable in the same ways a text box is editable and the content we
  // want to be read out by a screen reader does not always align with the edits
  // (selection changes) that happen in the terminal window. Use the log role so
  // that the screen reader doesn't treat it like a text box and announce all
  // selection changes. The announcements that we want spoken are generated
  // by a separate live region, which gives more control over what will be
  // spoken.
  this.screen_.setAttribute('role', 'log');
  this.screen_.setAttribute('aria-live', 'off');
  this.screen_.setAttribute('aria-roledescription', 'Terminal');

  // Set aria-readonly to indicate to the screen reader that the text on the
  // screen is not modifiable by the html cursor. It may be modifiable by
  // sending input to the application running in the terminal, but this is
  // orthogonal to the DOM's notion of modifiable.
  this.screen_.setAttribute('aria-readonly', 'true');
  this.screen_.setAttribute('tabindex', '-1');
  this.screen_.style.cssText = `
      background-color: rgb(var(--hterm-background-color));
      caret-color: transparent;
      color: rgb(var(--hterm-foreground-color));
      display: block;
      font-family: monospace;
      font-size: 15px;
      font-variant-ligatures: none;
      height: 100%;
      overflow-y: scroll; overflow-x: hidden;
      white-space: pre;
      width: 100%;
      outline: none !important;
  `;


  /**
   * @param {function(...)} f
   * @return {!EventListener}
   */
  const el = (f) => /** @type {!EventListener} */ (f);
  this.screen_.addEventListener('scroll', el(this.onScroll_.bind(this)));
  this.screen_.addEventListener('wheel', el(this.onScrollWheel_.bind(this)));
  this.screen_.addEventListener('touchstart', el(this.onTouch_.bind(this)));
  this.screen_.addEventListener('touchmove', el(this.onTouch_.bind(this)));
  this.screen_.addEventListener('touchend', el(this.onTouch_.bind(this)));
  this.screen_.addEventListener('touchcancel', el(this.onTouch_.bind(this)));
  this.screen_.addEventListener('cut', el(this.onCopy_.bind(this))); // iOS addition
  this.screen_.addEventListener('copy', el(this.onCopy_.bind(this)));
  this.screen_.addEventListener('paste', el(this.onPaste_.bind(this)));
  this.screen_.addEventListener('drop', el(this.onDragAndDrop_.bind(this)));

  doc.body.addEventListener('keydown', this.onBodyKeyDown_.bind(this));

  // Add buttons to make accessible scrolling through terminal history work
  // well. These are positioned off-screen until they are selected, at which
  // point they are moved on-screen.
  const a11yButtonHeight = 30;
  const a11yButtonBorder = 1;
  const a11yButtonTotalHeight = a11yButtonHeight + 2 * a11yButtonBorder;
  const a11yButtonStyle = `
    border-style: solid;
    border-width: ${a11yButtonBorder}px;
    color: rgb(var(--hterm-foreground-color));
    cursor: pointer;
    font-family: monospace;
    font-weight: bold;
    height: ${a11yButtonHeight}px;
    line-height: ${a11yButtonHeight}px;
    padding: 0 8px;
    position: fixed;
    right: var(--hterm-screen-padding-size);
    text-align: center;
    z-index: 1;
  `;
  // Note: we use a <div> rather than a <button> because we don't want it to be
  // focusable. If it's focusable this interferes with the contenteditable
  // focus.
  	// iOS, TODO: disable scrollUpButton if it interferes with voiceOver
  this.scrollUpButton_ = this.document_.createElement('div');
  this.scrollUpButton_.id = 'hterm:a11y:page-up';
  this.scrollUpButton_.innerText = hterm.msg('BUTTON_PAGE_UP', [], 'Page up');
  this.scrollUpButton_.setAttribute('role', 'button');
  this.scrollUpButton_.style.cssText = a11yButtonStyle;
  this.scrollUpButton_.style.top = `${-a11yButtonTotalHeight}px`;
  this.scrollUpButton_.addEventListener('click', this.scrollPageUp.bind(this));

  this.scrollDownButton_ = this.document_.createElement('div');
  this.scrollDownButton_.id = 'hterm:a11y:page-down';
  this.scrollDownButton_.innerText =
      hterm.msg('BUTTON_PAGE_DOWN', [], 'Page down');
  this.scrollDownButton_.setAttribute('role', 'button');
  this.scrollDownButton_.style.cssText = a11yButtonStyle;
  this.scrollDownButton_.style.bottom = `${-a11yButtonTotalHeight}px`;
  this.scrollDownButton_.addEventListener(
      'click', this.scrollPageDown.bind(this));

  this.optionsButton_ = this.document_.createElement('div');
  this.optionsButton_.id = 'hterm:a11y:options';
  this.optionsButton_.innerText =
      hterm.msg('OPTIONS_BUTTON_LABEL', [], 'Options');
  this.optionsButton_.setAttribute('role', 'button');
  this.optionsButton_.style.cssText = a11yButtonStyle;
  this.optionsButton_.style.bottom = `${-2 * a11yButtonTotalHeight}px`;
  this.optionsButton_.addEventListener(
      'click', this.publish.bind(this, 'options'));

  doc.body.appendChild(this.scrollUpButton_);
  doc.body.appendChild(this.screen_);
  doc.body.appendChild(this.scrollDownButton_);
  doc.body.appendChild(this.optionsButton_);

  // We only allow the scroll buttons to display after a delay, otherwise the
  // page up button can flash onto the screen during the intial change in focus.
  // This seems to be because it is the first element inside the <x-screen>
  // element, which will get focussed on page load.
  this.allowA11yButtonsToDisplay_ = false;
  setTimeout(() => { this.allowA11yButtonsToDisplay_ = true; }, 500);
  this.document_.addEventListener('selectionchange', () => {
    this.selection.sync();

    if (!this.allowA11yButtonsToDisplay_) {
      return;
    }

    const accessibilityEnabled = this.accessibilityReader_ &&
        this.accessibilityReader_.accessibilityEnabled;

    const selection = this.document_.getSelection();
    let selectedElement;
    if (selection.anchorNode && selection.anchorNode.parentElement) {
      selectedElement = selection.anchorNode.parentElement;
    }
    if (accessibilityEnabled && selectedElement == this.scrollUpButton_) {
      this.scrollUpButton_.style.top = `${this.screenPaddingSize}px`;
    } else {
      this.scrollUpButton_.style.top = `${-a11yButtonTotalHeight}px`;
    }
    if (accessibilityEnabled && selectedElement == this.scrollDownButton_) {
      this.scrollDownButton_.style.bottom = `${this.screenPaddingSize}px`;
    } else {
      this.scrollDownButton_.style.bottom = `${-a11yButtonTotalHeight}px`;
    }
    if (accessibilityEnabled && selectedElement == this.optionsButton_) {
      this.optionsButton_.style.bottom = `${this.screenPaddingSize}px`;
    } else {
      this.optionsButton_.style.bottom = `${-2 * a11yButtonTotalHeight}px`;
    }
  });

  // This is the main container for the fixed rows.
  this.rowNodes_ = doc.createElement('div');
  this.rowNodes_.id = 'hterm:row-nodes';
  this.rowNodes_.style.cssText = (
      'display: block;' +
      'position: fixed;' +
      'overflow: hidden;' +
      'user-select: text;');
  this.screen_.appendChild(this.rowNodes_);

  // Two nodes to hold offscreen text during the copy event.
  this.topSelectBag_ = doc.createElement('x-select-bag');
  this.topSelectBag_.style.cssText = (
      'display: block;' +
      'overflow: hidden;' +
      'height: var(--hterm-charsize-height);' +
      'white-space: pre;');

  this.bottomSelectBag_ = this.topSelectBag_.cloneNode();

  // Nodes above the top fold and below the bottom fold are hidden.  They are
  // only used to hold rows that are part of the selection but are currently
  // scrolled off the top or bottom of the visible range.
  this.topFold_ = doc.createElement('x-fold');
  this.topFold_.id = 'hterm:top-fold-for-row-selection';
  this.topFold_.style.cssText = `
    display: block;
    height: var(--hterm-screen-padding-size);
  `;
  this.rowNodes_.appendChild(this.topFold_);

  this.bottomFold_ = this.topFold_.cloneNode();
  this.bottomFold_.id = 'hterm:bottom-fold-for-row-selection';
  this.rowNodes_.appendChild(this.bottomFold_);

  // This hidden div accounts for the vertical space that would be consumed by
  // all the rows in the buffer if they were visible.  It's what causes the
  // scrollbar to appear on the 'x-screen', and it moves within the screen when
  // the scrollbar is moved.
  //
  // It is set 'visibility: hidden' to keep the browser from trying to include
  // it in the selection when a user 'drag selects' upwards (drag the mouse to
  // select and scroll at the same time).  Without this, the selection gets
  // out of whack.
  this.scrollArea_ = doc.createElement('div');
  this.scrollArea_.id = 'hterm:scrollarea';
  this.scrollArea_.style.cssText = 'visibility: hidden';
  this.screen_.appendChild(this.scrollArea_);

  // We send focus to this element just before a paste happens, so we can
  // capture the pasted text and forward it on to someone who cares.
  this.pasteTarget_ = doc.createElement('textarea');
  this.pasteTarget_.id = 'hterm:ctrl-v-paste-target';
  this.pasteTarget_.setAttribute('tabindex', '-1');
  this.pasteTarget_.setAttribute('aria-hidden', 'true');
  this.pasteTarget_.style.cssText = (
    'position: absolute;' +
    'height: 1px;' +
    'width: 1px;' +
    'left: 0px; ' +
    'bottom: 0px;' +
    'opacity: 0');
  this.pasteTarget_.contentEditable = true;

  this.screen_.appendChild(this.pasteTarget_);
  this.pasteTarget_.addEventListener(
      'textInput', this.handlePasteTargetTextInput_.bind(this));

  this.resize();
};

/**
 * Handler for touch events.
 *
 * @param {!TouchEvent} e
 */
hterm.ScrollPort.prototype.onTouch_ = function(e) {

	// TODO: disable scrolling with stylus *if* scribble is enabled. 
	// Stylus and finger are both touch. but e.touches[0].touchType is 'stylus' for stylus touches.
	// Now the question is how do I know that scribble is enabled?
	
  this.onTouch(e);

  if (e.defaultPrevented) {
    return;
  }

  // Extract the fields from the Touch event that we need.  If we saved the
  // event directly, it has references to other objects (like x-row) that
  // might stick around for a long time.  This way we only have small objects
  // in our lastTouch_ state.
  const scrubTouch = function(t) {
    return {
      id: t.identifier,
      y: t.clientY,
      x: t.clientX,
    };
  };

  let i, touch;
  switch (e.type) {
    case 'touchstart':
      // Workaround focus bug on CrOS if possible.
      // TODO(vapier): Drop this once https://crbug.com/919222 is fixed.
      if (hterm.os == 'cros' && window.chrome && chrome.windows) {
        chrome.windows.getCurrent((win) => {
          if (!win.focused) {
            chrome.windows.update(win.id, {focused: true});
          }
        });
      }

      // Save the current set of touches.
      for (i = 0; i < e.changedTouches.length; ++i) {
        touch = scrubTouch(e.changedTouches[i]);
        this.lastTouch_[touch.id] = touch;
      }
      break;

    case 'touchcancel':
    case 'touchend':
    	  // iOS addition:
      if (Object.values(this.lastTouch_).length == 1) {
      	  // single touch
        touch = scrubTouch(e.changedTouches[0]);
        if ((this.lastTouch_[touch.id].y == touch.y) && (this.lastTouch_[touch.id].x == touch.x)) {
        	var xcursor = (touch.x / this.characterSize.width);
        	var ycursor = (touch.y / this.characterSize.height);
        	if (window.term_.moveCursorPosition) {
				window.term_.moveCursorPosition(Math.floor(ycursor), Math.floor(xcursor));
			}
		} 
	  }    	  
      // Throw away existing touches that we're finished with.
      for (i = 0; i < e.changedTouches.length; ++i) {
        delete this.lastTouch_[e.changedTouches[i].identifier];
      }
      break;

    case 'touchmove': {
      const selection = term_.document_.getSelection();
      if (selection.isCollapsed) {
		  e.preventDefault(); // iOS: prevent WKWebView from scrolling too.
      }
      // Walk all of the touches in this one event and merge all of their
      // changes into one delta.  This lets multiple fingers scroll faster.
      let delta = 0;
      for (i = 0; i < e.changedTouches.length; ++i) {
        touch = scrubTouch(e.changedTouches[i]);
        delta += (this.lastTouch_[touch.id].y - touch.y);
        this.lastTouch_[touch.id] = touch;
      }

      // Invert to match the touchscreen scrolling direction of browser windows.
      delta *= -1;

      let top = this.screen_.scrollTop - delta;
      if (top < 0) {
        top = 0;
      }

      const scrollMax = this.getScrollMax_();
      if (top > scrollMax) {
        top = scrollMax;
      }

      if (top != this.screen_.scrollTop) {
        // Moving scrollTop causes a scroll event, which triggers the redraw.
        this.screen_.scrollTop = top;
      }
      break;
    }
  }

  // To disable gestures or anything else interfering with our scrolling.
  // iOS: we need the system to handle this touch event, so we can copy-paste.
  // e.preventDefault();
};

/**
 * Handle textInput events.
 *
 * These are generated when using IMEs, Virtual Keyboards (VKs), compose keys,
 * Unicode input, etc...
 *
 * @param {!InputEvent} e The event to process.
 */
hterm.Keyboard.prototype.onTextInput_ = function(e) {
  if (!e.data) {
    return;
  }

  // Just pass the generated buffer straight down.  No need for us to split it
  // up or otherwise parse it ahead of times.
  this.terminal.onVTKeystroke(e.data);
  e.preventDefault(); // iOS: prevent WkWebView from inserting CJK characters a second time
};

/**
 * React when the user tries to copy from the scrollPort.
 *
 * @param {!Event} e The DOM copy event.
 */
hterm.Terminal.prototype.onCopy_ = function(e) {
	// iOS change: handle cut events ourselves
	if (e.type == 'cut') {
		this.onCut(e);
		return;
	}
	// iOS 26: the useDefaultWindowCopy setting is not set by iOS
	// Beta issue or iOS != iPadOS issue?
	// if (!this.useDefaultWindowCopy) {
		e.preventDefault();
		setTimeout(this.copySelectionToClipboard.bind(this), 0);
	// }
	// iOS: clear selection after copy
	if (this.clearSelectionAfterCopy) {
		var selection = this.getDocument().getSelection();
		setTimeout(selection.collapseToEnd.bind(selection), 50);
	}  	
};

/**
 * Copy the specified text to the system clipboard.
 *
 * We'll create selections on demand based on the content to copy.
 *
 * @param {!Document} document The document with the selection to copy.
 * @param {string} str The string data to copy out.
 * @return {!Promise<void>}
 */
hterm.copySelectionToClipboard = function(document, str) {
	window.webkit.messageHandlers.aShell.postMessage('copy:' + str); // copy the text to the iOS clipboard. 
}

/**
 * Set the width of the terminal, resizing the UI to match.
 *
 * @param {number} columnCount
 */
hterm.Terminal.prototype.setWidth = function(columnCount) {
  if (columnCount == null) {
    this.div_.style.width = '100%';
    return;
  }

  this.div_.style.width = Math.ceil(
      this.scrollPort_.characterSize.width *
      columnCount + this.scrollPort_.currentScrollbarWidthPx) - 2 + 'px';
  // iOS difference is in the "-2"
  this.realizeSize_(columnCount, this.screenSize.height);
  this.scheduleSyncCursorPosition_();
};

/**
 * Set the color for the cursor.
 *
 * If you want this setting to persist, set it through prefs_, rather than
 * with this method.
 *
 * @param {string=} color The color to set.  If not defined, we reset to the
 *     saved user preference.
 */
hterm.Terminal.prototype.setCursorColor = function(color) {
	if (color === undefined)
		color = this.prefs_.get('cursor-color');
	// iOS change: too early in the process, bail out
	if (color === undefined) 
		return;

	this.setCssVar('cursor-color', color);
	this.setCssVar('caret-color', color); // iOS 13 addition
	if (this.scrollPort_.screen_ != undefined) {
		this.scrollPort_.screen_.style.setProperty('caret-color', color); // iOS 13 addition
	}
};

// iOS addition. Make sure the text displayed is resized.
hterm.Terminal.prototype.setFontFamily = function(n) {
  this.scrollPort_.setFontFamily(n);
  this.setCssVar('charsize-width', this.scrollPort_.characterSize.width + 'px');
  this.setCssVar('charsize-height',
                 this.scrollPort_.characterSize.height + 'px');
};

/**
 * Deal with terminal width changes.
 *
 * This function does what needs to be done when the terminal width changes
 * out from under us.  It happens here rather than in onResize_() because this
 * code may need to run synchronously to handle programmatic changes of
 * terminal width.
 *
 * Relying on the browser to send us an async resize event means we may not be
 * in the correct state yet when the next escape sequence hits.
 *
 * @param {number} columnCount The number of columns.
 */
hterm.Terminal.prototype.realizeWidth_ = function(columnCount) {
  if (columnCount <= 0) {
    throw new Error('Attempt to realize bad width: ' + columnCount);
  }

  // iOS addition: reset the caret at each resize (includes switching to/from alternate screen)
  if ((window.term_ != undefined) && (window.term_.ready_)) {
  	if (!this.isPrimaryScreen() && window.commandRunning.startsWith('vim')) {
  		this.setCssVar('caret-color', 'transparent'); // iOS 13 addition
  		this.scrollPort_.screen_.style.setProperty('caret-color', 'transparent'); // iOS 13 addition
  		this.scrollPort_.screen_.style.setProperty('--hterm-caret-color', 'transparent'); // iOS 13 addition
  		document.getElementsByTagName("html")[0].style.setProperty('caret-color', 'transparent'); 
  		document.getElementsByTagName("html")[0].style.setProperty('--hterm-caret-color', 'transparent'); 
  	} else {
		color = this.getCssVar('cursor-color');
		if (color != window.cursorColor) {
			this.setCursorColor(window.cursorColor); 
		}
  	}
  }
  const deltaColumns = columnCount - this.screen_.getWidth();
  if (deltaColumns == 0) {
    // No change, so don't bother recalculating things.
    return;
  }

  this.screenSize.width = columnCount;
  this.screen_.setColumnCount(columnCount);

  if (deltaColumns > 0) {
    if (this.defaultTabStops) {
      this.setDefaultTabStops(this.screenSize.width - deltaColumns);
    }
  } else {
    for (let i = this.tabStops_.length - 1; i >= 0; i--) {
      if (this.tabStops_[i] < columnCount) {
        break;
      }

      this.tabStops_.pop();
    }
  }

  this.screen_.setColumnCount(this.screenSize.width);
  // iOS: rewrite everything after each resize:
  if ((window.term_ != undefined) && (window.term_.ready_)) {
  	// Check that config has been set:
	if (window.foregroundColor != undefined) {
	  if (window.term_.getForegroundColor() === undefined) {
	    window.term_.setForegroundColor(window.foregroundColor);
	    window.term_.prefs_.set('foreground-color', window.foregroundColor);
	  }
	}
	if (window.backgroundColor != undefined) {
	  if (window.term_.getBackgroundColor() === undefined) {
		  window.term_.setBackgroundColor(window.backgroundColor);
		  window.term_.prefs_.set('background-color', window.backgroundColor);
	  }
	}
	if (window.fontSize != undefined) {
	  if (window.term_.getFontSize() === undefined) {
	  	window.term_.setFontSize(window.fontSize); 
	  	window.term_.prefs_.set('font-size', window.fontSize); 
	  }
	}
	if (window.fontFamily != undefined) {
	  if (window.term_.getFontFamily() === undefined) {
	  	window.term_.setFontFamily(window.fontFamily); 
	  	window.term_.prefs_.set('font-family', window.fontFamily);
	  }
	}
	if (window.cursorColor != undefined) {
	  if (window.term_.getCursorColor() === undefined) {
	  	window.term_.setCursorColor(window.cursorColor);
	  	window.term_.prefs_.set('cursor-color', window.cursorColor);
	  }
	}
	if (window.cursorShape != undefined) {
	  if (window.term_.getCursorShape() === undefined) {
	  	window.term_.setCursorShape(window.cursorShape);
	  	window.term_.prefs_.set('cursor-shape', window.cursorShape);
	  }
	}
  	// only rewrite content for primary screen:
  	if (this.isPrimaryScreen()) {
	  if ((window.printedContent !== undefined) && (window.printedContent != 'undefined')) {
	  	let content = window.printedContent; 
	  	window.term_.wipeContents();
	  	window.printedContent = '';
		window.duringResize = true;
		this.io.print(content);
		window.duringResize = false;
	  }
  	}
  }
};

/**
 * Write a UTF-16 JavaScript string to the terminal.
 *
 * @param {string} string The string to print.
 */
hterm.Terminal.IO.prototype.print =
hterm.Terminal.IO.prototype.writeUTF16 = function(string) {
  // If another process has the foreground IO, buffer new data sent to this IO
  // (since it's in the background).  When we're made the foreground IO again,
  // we'll flush everything.
  if (this.terminal_.io != this) {
    this.buffered_ += string;
    return;
  }

  // iOS: keep a copy of everything that has been sent to the screen, 
  // to restore terminal status later and resize.
  if (this.terminal_.isPrimaryScreen()) {
     window.printedContent += string;
  }
 
  this.terminal_.interpret(string);
};


// If a command sends a Cursor Position Request (CPR), then it must be an interactive command, 
// so we set up window.interactiveCommandRunning to true. There are two CPR functions. The former
// seems to be used more often than the latter.
/**
 * Device Status Report (DSR, DEC Specific).
 *
 * 5 - Status Report. Result (OK) is CSI 0 n
 * 6 - Report Cursor Position (CPR) [row;column]. Result is CSI r ; c R
 *
 * @this {!hterm.VT}
 * @param {!hterm.VT.ParseState} parseState
 */
hterm.VT.CSI['n'] = function(parseState) {
  // window.webkit.messageHandlers.aShell.postMessage('CPR request (n) ' + parseState.args);
  if (parseState.args[0] == 5) {
    this.terminal.io.sendString('\x1b0n');
  } else if (parseState.args[0] == 6) {
	if ((window.commandRunning !== undefined) && (window.commandRunning != '') && (!window.duringResize)) {
		window.interactiveCommandRunning = true;
		const row = this.terminal.getCursorRow() + 1;
		const col = this.terminal.getCursorColumn() + 1;
		this.terminal.io.sendString('\x1b[' + row + ';' + col + 'R');
	}
  }
};

/**
 * Device Status Report (DSR, DEC Specific).
 *
 * 6  - Report Cursor Position (CPR) [row;column] as CSI ? r ; c R
 * 15 - Report Printer status as CSI ? 1 0 n (ready) or
 *      CSI ? 1 1 n (not ready).
 * 25 - Report UDK status as CSI ? 2 0 n (unlocked) or CSI ? 2 1 n (locked).
 * 26 - Report Keyboard status as CSI ? 2 7 ; 1 ; 0 ; 0 n (North American).
 *      The last two parameters apply to VT400 & up, and denote keyboard ready
 *      and LK01 respectively.
 * 53 - Report Locator status as CSI ? 5 3 n Locator available, if compiled-in,
 *      or CSI ? 5 0 n No Locator, if not.
 *
 * @this {!hterm.VT}
 * @param {!hterm.VT.ParseState} parseState
 */
hterm.VT.CSI['?n'] = function(parseState) {
  // window.webkit.messageHandlers.aShell.postMessage('CPR request (?n) ' + parseState.args);
  if (parseState.args[0] == 6) {
	if ((window.commandRunning !== undefined) && (window.commandRunning != '') && (!window.duringResize)) {
		window.interactiveCommandRunning = true;
		const row = this.terminal.getCursorRow() + 1;
		const col = this.terminal.getCursorColumn() + 1;
		this.terminal.io.sendString('\x1b[' + row + ';' + col + 'R');
	}
  } else if (parseState.args[0] == 15) {
    this.terminal.io.sendString('\x1b[?11n');
  } else if (parseState.args[0] == 25) {
    this.terminal.io.sendString('\x1b[?21n');
  } else if (parseState.args[0] == 26) {
    this.terminal.io.sendString('\x1b[?12;1;0;0n');
  } else if (parseState.args[0] == 53) {
    this.terminal.io.sendString('\x1b[?50n');
  }
};

/**
 * Set a preference to a specific value.
 *
 * This will dispatch the onChange handler if the preference value actually
 * changes.
 *
 * @param {string} name The preference to set.
 * @param {*} newValue The value to set.  Anything that can be represented in
 *     JSON is a valid value.
 * @param {function()=} onComplete Callback when the set call completes.
 * @param {boolean=} saveToStorage Whether to commit the change to the backing
 *     storage or only the in-memory record copy.
 * @return {!Promise<void>} Promise which resolves once all observers are
 *     notified.
 */
// synchronous version, to be used when called from Swift/WKWebView
lib.PreferenceManager.prototype.setSync = function(
    name, newValue, onComplete = undefined, saveToStorage = true) {
  const record = this.prefRecords_[name];
  if (!record) {
    throw new Error('Unknown preference: ' + name);
  }

  const oldValue = record.get();

  if (!this.diff(oldValue, newValue)) {
    return; 
  }

  if (this.diff(record.defaultValue, newValue)) {
    record.currentValue = newValue;
    if (saveToStorage) {
      this.storage.setItem(this.prefix + name, newValue).then(onComplete);
    }
  } else {
    record.currentValue = this.DEFAULT_VALUE;
    if (saveToStorage) {
      this.storage.removeItem(this.prefix + name).then(onComplete);
    }
  }

  // We need to manually send out the notification on this instance.  If we
  // The storage event won't fire a notification because we've already changed
  // the currentValue, so it won't see a difference.  If we delayed changing
  // currentValue until the storage event, a pref read immediately after a write
  // would return the previous value.
  this.notifyChange_(name);
};


/**
 * Select the font-family and font-smoothing for this scrollport.
 *
 * @param {string} fontFamily Value of the CSS 'font-family' to use for this
 *     scrollport.  Should be a monospace font.
 * @param {string=} smoothing Optional value for '-webkit-font-smoothing'.
 *     Defaults to an empty string if not specified.
 */
// iOS edit: added a backup font in case the requested font cannot be loaded. It has to be hardcoded.
hterm.ScrollPort.prototype.setFontFamily = function(fontFamily, smoothing = '') {
	this.screen_.style.fontFamily = fontFamily + ", Menlo, monospace";
  this.screen_.style.webkitFontSmoothing = smoothing;

  this.syncCharacterSize();
};

/**
 * Handle font zooming.
 *
 * @param {!KeyboardEvent} e The event to process.
 * @param {!hterm.Keyboard.KeyDef} keyDef Key definition.
 * @return {symbol|string} Key action or sequence.
 */
// iOS edit: tell the Swift part of the change in font size
hterm.Keyboard.KeyMap.prototype.onZoom_ = function(e, keyDef) {
  if (this.keyboard.ctrlPlusMinusZeroZoom === e.shiftKey) {
    // If ctrl-PMZ controls zoom and the shift key is pressed, or
    // ctrl-shift-PMZ controls zoom and this shift key is not pressed,
    // then we want to send the control code instead of affecting zoom.
    if (keyDef.keyCap == '-_') {
      // ^_
      return '\x1f';
    }

    // Only ^_ is valid, the other sequences have no meaning.
    return hterm.Keyboard.KeyActions.CANCEL;
  }

  const cap = keyDef.keyCap.substr(0, 1);
  if (cap == '0') {
      this.keyboard.terminal.setFontSize(0);
  } else {
    let size = this.keyboard.terminal.getFontSize();

    if (cap == '-' || keyDef.keyCap == '[KP-]') {
      size -= 1;
    } else {
      size += 1;
    }

    window.fontSize = size;
    this.keyboard.terminal.setFontSize(size);
	window.webkit.messageHandlers.aShell.postMessage('setFontSize:' + size);
  }

  return hterm.Keyboard.KeyActions.CANCEL;
};

/**
 * Set the font size for this terminal.
 *
 * Call setFontSize(0) to reset to the default font size.
 *
 * This function does not modify the font-size preference.
 *
 * @param {number} px The desired font size, in pixels.
 */
hterm.Terminal.prototype.setFontSize = function(px) {
	// a bit strong, but trying to prevent arbitrary changes in font size with StageManager.
	px = window.fontSize;

	this.scrollPort_.setFontSize(px);
	this.setCssVar('font-size', `${px}px`);
	this.setCssVar('font-variant-ligatures', `normal`, prefix=''); // activate ligatures (doesn't work, but still)
	this.updateCssCharsize_();
};


/**
 * Handle keypress events.
 *
 * TODO(vapier): Drop this event entirely and only use keydown.
 *
 * @param {!KeyboardEvent} e The event to process.
 */
hterm.Keyboard.prototype.onKeyPress_ = function(e) {
  // FF doesn't set keyCode reliably in keypress events.  Stick to the which
  // field here until we can move to keydown entirely.
  const key = String.fromCharCode(e.which).toLowerCase();
  if ((e.ctrlKey || e.metaKey) && (key == 'c' || key == 'v')) {
    // On FF the key press (not key down) event gets fired for copy/paste.
    // Let it fall through for the default browser behavior.
    return;
  }

  if (e.keyCode == 9 /* Tab */) {
    // On FF, a key press event will be fired in addition of key down for the
    // Tab key if key down isn't handled. This would only happen if a custom
    // PASS binding has been created and therefore this should be handled by the
    // browser.
    return;
  }

  /** @type {string} */
  let ch;
  if (e.altKey && this.altSendsWhat == 'browser-key' && e.charCode == 0) {
    // If we got here because we were expecting the browser to handle an
    // alt sequence but it didn't do it, then we might be on an OS without
    // an enabled IME system.  In that case we fall back to xterm-like
    // behavior.
    //
    // This happens here only as a fallback.  Typically these platforms should
    // set altSendsWhat to either 'escape' or '8-bit'.
    ch = String.fromCharCode(e.keyCode);
    if (!e.shiftKey) {
      ch = ch.toLowerCase();
    }

  } else if (e.charCode >= 32) {
    // iOS: fromCodePoint to get the first character, key to get the full (composed) emoji
	ch = e.key;
    // ch = String.fromCodePoint(e.charCode);
  }

  if (ch) {
    this.terminal.onVTKeystroke(ch);
  }

  e.preventDefault();
  e.stopPropagation();
};

/* 
 * Changes to hterm_all.js that are just bug fixes, nothing specific to a-Shell
 */

/**
 * Take any valid CSS color definition and turn it into an rgb or rgba value.
 *
 * @param {string} def The CSS color spec to normalize.
 * @return {?string} The converted value.
 */
// iOS edit: avoid raising an error if def === undefined
lib.colors.normalizeCSS = function(def) {
  if (def == undefined) {
  	  return lib.colors.hexToRGB("#000000");
  }
  if (def.startsWith('#')) {
    return lib.colors.hexToRGB(def);
  }

  if (lib.colors.re_.rgbx.test(def)) {
    return def;
  }

  if (lib.colors.re_.hslx.test(def)) {
    return lib.colors.hslToRGB(def);
  }

  return lib.colors.nameToRGB(def);
};

/**
 * Select all rows in the viewport.
 */
hterm.ScrollPort.prototype.selectAll = function() {
  let firstRow;

  if (this.topFold_.nextSibling.rowIndex != 0) {
    while (this.topFold_.previousSibling) {
      this.rowNodes_.removeChild(this.topFold_.previousSibling);
    }

    firstRow = this.fetchRowNode_(0);
    this.rowNodes_.insertBefore(firstRow, this.topFold_);
    this.syncRowNodesDimensions_();
  } else {
    firstRow = this.topFold_.nextSibling;
  }

  const lastRowIndex = this.rowProvider_.getRowCount() - 1;
  let lastRow;

  if (this.bottomFold_.previousSibling.rowIndex != lastRowIndex) {
    while (this.bottomFold_.nextSibling) {
      this.rowNodes_.removeChild(this.bottomFold_.nextSibling);
    }

    lastRow = this.fetchRowNode_(lastRowIndex);
    this.rowNodes_.appendChild(lastRow);
  } else {
  	// iOS bug fix: lastRow must be a rowNode, not an integer
    // lastRow = this.bottomFold_.previousSibling.rowIndex;
    lastRow = this.fetchRowNode_(this.bottomFold_.previousSibling.rowIndex);
  }

  const selection = this.document_.getSelection();
  selection.collapse(firstRow, 0);
  selection.extend(lastRow, lastRow.childNodes.length);

  this.selection.sync();
};

/**
 * Handler for scroll events.
 *
 * The onScroll event fires when scrollArea's scrollTop property changes.  This
 * may be due to the user manually move the scrollbar, or a programmatic change.
 *
 * @param {!Event} e
 */
hterm.ScrollPort.prototype.onScroll_ = function(e) {
	// If the user has selected something, exit. Let them continue
	// the selection.
	const selection = term_.document_.getSelection();
	if (!selection.isCollapsed) {
		// evt.preventDefault(); // iOS: prevent WKWebView from scrolling too.
		return;
	}

    const screenSize = this.getScreenSize();
    if (screenSize.width != this.lastScreenWidth_ ||
    screenSize.height != this.lastScreenHeight_) {
        // This event may also fire during a resize (but before the resize event!).
        // This happens when the browser moves the scrollbar as part of the resize.
        // In these cases, we want to ignore the scroll event and let onResize
        // handle things.  If we don't, then we end up scrolling to the wrong
        // position after a resize.
        this.resize();
        return;
    }

    this.redraw_();
    this.publish('scroll', {
        scrollPort: this
    });
};

/**
 * Handle pasted data.
 *
 * @param {string} data The pasted data.
 */
hterm.Terminal.prototype.onPasteData_ = function(data) {
	data = data.replace(/\n/mg, '\r ');
	// We strip out most escape sequences as they can cause issues (like
	// inserting an \x1b[201~ midstream).  We pass through whitespace
	// though: 0x08:\b 0x09:\t 0x0a:\n 0x0d:\r.
	// This matches xterm behavior.
	// eslint-disable-next-line no-control-regex
	const filter = (data) => data.replace(/[\x00-\x07\x0b-\x0c\x0e-\x1f]/g, '');
	data = filter(data);

	this.io.sendString(data);
};

