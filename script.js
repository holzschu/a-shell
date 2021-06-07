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
	let interactiveRegexp = /^less|^more|^ssh|^scp|^sftp|\|&? *less|\|&? *more|^man/;
	return interactiveRegexp.test(commandString) 
	// It's easier to match a regexp, then take the negation than to test a regexp that does not contain a pattern:
	// This is disabled for now, but kept in case it can become useful again.
	// let notInteractiveRegexp = /^ssh-keygen/;
	// return interactiveRegexp.test(commandString) && !notInteractiveRegexp.test(commandString);
}

// standard functions (terminal, autocomplete, etc)
var lastDirectory = '';
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
}

function isLetter(c) {
	// TODO: extension for CJK characters (hard)
	return (c.toLowerCase() != c.toUpperCase());
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
		window.interactiveCommandRunning = false;
	} else {
		// let the running command print its own prompt:
		window.webkit.messageHandlers.aShell.postMessage('input:' + '\n');
	}
}

function updatePromptPosition() {
	window.promptEnd = window.term_.screen_.cursorPosition.column;
	// required because some commands can take several lines, especially on a phone.
	window.promptLine = window.term_.screen_.cursorPosition.row;
	window.promptScroll = window.term_.scrollPort_.getTopRowIndex();
	currentCommandCursorPosition = 0; 
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

	const currentChar = window.term_.io.currentCommand[currentCommandCursorPosition - 1];
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
	window.term_.io.currentCommand = window.term_.io.currentCommand.slice(0, currentCommandCursorPosition - 1) + endOfCommand;
	currentCommandCursorPosition -= 1;
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
	if (n < predicate.length) {
		var predicate = predicate.substr(n + 1);
	}
	n = predicate.lastIndexOf(" ");
	while ((n > 0) && (predicate[n-1] == "\\")) { 
		// escaped space
		n = predicate.lastIndexOf(" ", n - 1);
	}
	if (n < predicate.length) {
		var predicate = predicate.substr(n + 1);
	}
	n = predicate.lastIndexOf(">");
	if (n < predicate.length) {
		var predicate = predicate.substr(n + 1);
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
	var matchToCommands = false;
	if (beforePredicate.length == 0) {
		matchToCommands = true; // beginning of line, must be a command
	} else if (beforePredicate.slice(-1) == "|") {
		matchToCommands = true; // right after a pipe, must be a command
	}
	// otherwise, it's probably a file
	var numFound = 0; 
	var file = '';
	if (matchToCommands) { 
		for (var i = 0, len = commandList.length; i < len; i++) {
			if (commandList[i].startsWith(predicate)) {
				var value = commandList[i].replace(predicate, "") + ' '; // add a space at the end if it's a command; 
				autocompleteList[numFound] = value;
				lastFound = value; 
				numFound += 1;
			}
		}
	} else {
		if ((predicate[0] == "~") && (predicate.lastIndexOf("/") == -1)) {
			// string beginning with ~, with no / at the end: it's a bookmark.
			directory = '';
			file = predicate;
			if (lastDirectory == '~bookmarkNames') {
				// First, remove 
				for (var i = 0, len = fileList.length; i < len; i++) {
					if (fileList[i].startsWith(file)) {
						var value = fileList[i].replace(file, "")
						autocompleteList[numFound] = value; 
						lastFound = value; 
						numFound += 1;
					}
				}
			} else {
				// asynchronous communication. Will have to execute the rest of the command too.
				window.webkit.messageHandlers.aShell.postMessage('listBookmarks:');
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
					var directory = ".";
					file = predicate;
				}
			}
			// Need to get list of files from directory. 
			if (directory == lastDirectory) {
				// First, remove 
				for (var i = 0, len = fileList.length; i < len; i++) {
					if (fileList[i].startsWith(file)) {
						var value = fileList[i].replace(file, "")
						autocompleteList[numFound] = value; 
						lastFound = value; 
						numFound += 1;
					}
				}
			} else {
				// asynchronous communication. Will have to execute the rest of the command too.
				window.webkit.messageHandlers.aShell.postMessage('listDirectory:' + directory);
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
		if (file.length == 0) {
			while ((autocompleteList[autocompleteIndex][0] == ".") && (autocompleteIndex < autocompleteList.length - 1)) {
				autocompleteIndex += 1;
			} 
			if (autocompleteIndex == autocompleteList.length - 1) {
				// directory with only ".*" files
				autocompleteIndex = 0;
			}
		}
		printAutocompleteString(autocompleteList[autocompleteIndex]);
	} else {
		if (numFound == 1) {
			printString(lastFound);
			io.currentCommand = io.currentCommand.slice(0, currentCommandCursorPosition) + lastFound + 
				io.currentCommand.slice(currentCommandCursorPosition, io.currentCommand.length);
			currentCommandCursorPosition += lastFound.length;
		}
		disableAutocompleteMenu(); 
	}
}

function setupHterm() {
// setTimeout(() => {
	const term = new hterm.Terminal();
	// Default monospaced fonts installed: Menlo and Courier. 
	term.prefs_.set('cursor-shape', 'BLOCK'); 
	term.prefs_.set('font-family', window.fontFamily);
	term.prefs_.set('font-size', window.fontSize); 
	term.prefs_.set('foreground-color', window.foregroundColor);
	term.prefs_.set('background-color', window.backgroundColor);
	term.prefs_.set('cursor-color', window.cursorColor);
	term.prefs_.set('cursor-blink', false); 
	term.prefs_.set('enable-clipboard-notice', false); 
	term.prefs_.set('use-default-window-copy', true); 
	term.prefs_.set('clear-selection-after-copy', true); 
	term.prefs_.set('copy-on-select', false);
	term.prefs_.set('audible-bell-sound', '');
	term.prefs_.set('receive-encoding', 'utf-8'); 
	term.prefs_.set('meta-sends-escape', 'false'); 

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
			var startPosition = ((startRow - window.promptScroll - window.promptLine) * this.screenSize.width) + startOffset;
			var xcursor = startOffset;
			var cutText = this.io.currentCommand.slice(startPosition, startPosition + text.length); 
			if (cutText == text) {
				this.io.currentCommand =  this.io.currentCommand.slice(0, startPosition) + this.io.currentCommand.slice(startPosition + text.length, this.io.currentCommand.length); 
				xcursor += window.promptEnd;
			} else {
				// startOffset can sometimes be off by promptLength. 
				startPosition -= window.promptEnd; 
				var cutText = this.io.currentCommand.slice(startPosition, startPosition + text.length); 
				if (cutText == text) {
					this.io.currentCommand =  this.io.currentCommand.slice(0, startPosition) + this.io.currentCommand.slice(startPosition + text.length, this.io.currentCommand.length); 
				} else {
					// This happens too often.
					window.webkit.messageHandlers.aShell.postMessage("Cannot find text = " + text + " in " + this.io.currentCommand); 
					// Do not cut if we don't agree on what to cut
					if (e != null) {
						e.preventDefault();
					}
					return false; 
				}
			}
			// Move cursor to startLine, startOffset
			// We redraw the command ourselves because iOS removes extra spaces around the text.
			// var scrolledLines = window.promptScroll - term.scrollPort_.getTopRowIndex();
			// io.print('\x1b[' + (window.promptLine + scrolledLines + 1) + ';' + (window.promptEnd + 1) + 'H'); // move cursor to position at start of line
			currentCommandCursorPosition = startPosition
			var ycursor = startRow - this.scrollPort_.getTopRowIndex();
			this.io.print('\x1b[' + (ycursor + 1) + ';' + (xcursor + 1) + 'H'); // move cursor to new position 
			this.io.print('\x1b[0J'); // delete display after cursor
			var endOfCommand = this.io.currentCommand.slice(startPosition, this.io.currentCommand.length); 
			this.io.print(endOfCommand); 
			this.io.print('\x1b[' + (ycursor + 1) + ';' + (xcursor + 1) + 'H'); // move cursor back to new position 
			window.webkit.messageHandlers.aShell.postMessage('copy:' + text); // copy the text to clipboard. We can't use JS fonctions because we removed the text.
			return true;
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
				// produce string = control + character 
				var charcode = string.toUpperCase().charCodeAt(0);
				string = String.fromCharCode(charcode - 64);
				window.controlOn = false;
				window.webkit.messageHandlers.aShell.postMessage('controlOff');
			}
			// always post keyboard input to TTY:
			window.webkit.messageHandlers.aShell.postMessage('inputTTY:' + string);
			// If help() is running in iPython, then it stops being interactive.
			var helpRunning = false;
			if (window.commandRunning.startsWith("ipython")) {
				var lastNewline = window.printedContent.lastIndexOf("\n");
				var lastLine = window.printedContent.substr(lastNewline + 2); // skip \n\r
				if (lastLine.startsWith("help>")) {
					helpRunning = true;
				} else if (lastLine.includes("Do you really want to exit ([y]/n)?")) {
					helpRunning = true;
				}
			}
			if (window.interactiveCommandRunning && !helpRunning) {
				// specific treatment for interactive commands: forward all keyboard input to them
				// window.webkit.messageHandlers.aShell.postMessage('sending: ' + string); // for debugging
				// post keyboard input to stdin
				window.webkit.messageHandlers.aShell.postMessage('inputInteractive:' + string);
			} else if ((window.commandRunning != '') && ((string.charCodeAt(0) == 3) || (string.charCodeAt(0) == 4))) {
				// Send control messages back to command:
				// first, flush existing input:
				if (io.currencCommand != '') {
					window.webkit.messageHandlers.aShell.postMessage('input:' + io.currentCommand);
					io.currentCommand = '';
				}
				window.webkit.messageHandlers.aShell.postMessage('input:' + string);
			} else { 
				if (io.currentCommand === '') { 
					// new line, reset things: (required for commands inside commands)
					updatePromptPosition(); 
				}
				var cursorPosition = term.screen_.cursorPosition.column - window.promptEnd;  // remove prompt length
				switch (string) {
					case '\r':
						if (autocompleteOn) {
							// Autocomplete menu being displayed + press return: select what's visible and remove
							pickCurrentValue();
							break;
						}
						// Before executing command, move to end of line if not already there:
						// Compute how many lines should we move downward:
						var beginCommand = io.currentCommand.slice(0, currentCommandCursorPosition); 
						var lineCursor = Math.floor((lib.wc.strWidth(beginCommand) + window.promptEnd)/ term.screenSize.width);
						var lineEndCommand = Math.floor((lib.wc.strWidth(io.currentCommand) + window.promptEnd)/ term.screenSize.width);
						for (var i = 0; i < lineEndCommand - lineCursor; i++) {
							io.println('');
						}
						io.println('');
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
								// Now is the time where we send the command to iOS: 
								window.webkit.messageHandlers.aShell.postMessage('shell:' + io.currentCommand);
								// and reinitialize:
								window.commandRunning = io.currentCommand;
								window.interactiveCommandRunning = isInteractive(window.commandRunning);
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
						if (currentCommandCursorPosition > 0) { 
							if (this.document_.getSelection().type == 'Range') {
								term.onCut(null); // remove the selection without copying it
							} else {
								deleteBackward();
							}
						}
						disableAutocompleteMenu();
						break;
					case String.fromCharCode(27):  // Escape. Make popup menu disappear
						disableAutocompleteMenu();
						break;
					case String.fromCharCode(27) + "[A":  // Up arrow
					case String.fromCharCode(27) + "[1;3A":  // Alt-Up arrow
					case String.fromCharCode(16):  // Ctrl+P
						if (window.commandRunning != '') {
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
								currentCommandCursorPosition = io.currentCommand.length;
							}
						} else {
							// popup menu being displayed, change it:
							if (autocompleteOn) {
								if (autocompleteIndex > 0) {
									autocompleteIndex -= 1; 
									printAutocompleteString(autocompleteList[autocompleteIndex]);
								}													
								break;
							}
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
								currentCommandCursorPosition = io.currentCommand.length;
							} 
						}
						break;
					case String.fromCharCode(27) + "[B":  // Down arrow
					case String.fromCharCode(27) + "[1;3B":  // Alt-Down arrow
					case String.fromCharCode(14):  // Ctrl+N
						if (window.commandRunning != '') {
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
								currentCommandCursorPosition = io.currentCommand.length;
							}
						} else {
							// popup menu being displayed, change it:
							if (autocompleteOn) {
								if (autocompleteIndex < autocompleteList.length - 1) {
									autocompleteIndex += 1; 
									printAutocompleteString(autocompleteList[autocompleteIndex]);
								}													
								break;
							}
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
								currentCommandCursorPosition = io.currentCommand.length;
							}
						}
						break;
					case String.fromCharCode(27) + "[D":  // Left arrow
					case String.fromCharCode(2):  // Ctrl+B
						if (this.document_.getSelection().type == 'Range') {
							// move cursor to start of selection
							this.moveCursorPosition(term.scrollPort_.selection.startRow.rowIndex - term.scrollPort_.getTopRowIndex(), term.scrollPort_.selection.startOffset);
							this.document_.getSelection().collapseToStart();
							disableAutocompleteMenu();
						} else {
							disableAutocompleteMenu();
							if (currentCommandCursorPosition > 0) { 
								var currentChar = io.currentCommand[currentCommandCursorPosition - 1];
								var currentCharWidth = lib.wc.strWidth(currentChar);
								this.document_.getSelection().empty();
								for (var i = 0; i < currentCharWidth; i++) {
									io.print('\b'); // move cursor back n chars, across lines
								}
								currentCommandCursorPosition -= 1;
								this.document_.getSelection().empty();
							}
						}
						break;
					case String.fromCharCode(27) + "[C":  // Right arrow
					case String.fromCharCode(6):  // Ctrl+F
						if (this.document_.getSelection().type == 'Range') {
							// move cursor to end of selection
							this.moveCursorPosition(term.scrollPort_.selection.endRow.rowIndex - term.scrollPort_.getTopRowIndex(), term.scrollPort_.selection.endOffset);
							this.document_.getSelection().collapseToEnd();
							disableAutocompleteMenu();
						} else {
							// recompute complete menu? For now, disable it.
							disableAutocompleteMenu();
							if (currentCommandCursorPosition < io.currentCommand.length) {
								var currentChar = io.currentCommand[currentCommandCursorPosition];
								var currentCharWidth = lib.wc.strWidth(currentChar);
								this.document_.getSelection().empty();
								if (term.screen_.cursorPosition.column < term.screenSize.width - currentCharWidth) {
									io.print('\x1b[' + currentCharWidth + 'C'); // move cursor forward n chars
								} else {
									io.print('\x1b[' + (term.screen_.cursorPosition.row + 2) + ';' + 0 + 'H'); // move cursor to start of next line
								}
								currentCommandCursorPosition += 1;
								this.document_.getSelection().empty();
							}
						}
						break; 
					case String.fromCharCode(27) + "[1;3D":  // Alt-left arrow
						disableAutocompleteMenu();
						if (currentCommandCursorPosition > 0) { // prompt.length
							while (currentCommandCursorPosition > 0) {
								currentCommandCursorPosition -= 1;
								var currentChar = io.currentCommand[currentCommandCursorPosition];
								var currentCharWidth = lib.wc.strWidth(currentChar);
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
								currentCommandCursorPosition += 1;
								var currentChar = io.currentCommand[currentCommandCursorPosition];
								var currentCharWidth = lib.wc.strWidth(currentChar);
								if (term.screen_.cursorPosition.column < term.screenSize.width - currentCharWidth) {
									io.print('\x1b[' + currentCharWidth + 'C'); // move cursor forward n chars
								} else {
									io.print('\x1b[' + (term.screen_.cursorPosition.row + 2) + ';' + 0 + 'H'); // move cursor to start of next line
								}
								if  (!isLetter(currentChar)) {
									break;
								}
							}
						}
						break;
					case String.fromCharCode(9):  // Tab, so autocomplete
						if (window.commandRunning == '') {
							if (autocompleteOn) {
								// hit tab when menu already visible = select current
								pickCurrentValue();
							} else {
								// Work on autocomplete list / current command
								updateAutocompleteMenu(io, currentCommandCursorPosition); 
							}
n						} else {
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
					case String.fromCharCode(4):  // Ctrl-D: deleter character after cursor TODO: test
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
						// clear entire line and move cursor to beginning of the line
						io.print('\x1b[2K\x1b[G');
						io.currentCommand = io.currentCommand
							.slice(currentCommandCursorPosition);
						currentCommandCursorPosition = 0;
						// redraw command line
						printPrompt();
						io.print(io.currentCommand);
						// move cursor back to beginning of the line
						io.print(`\x1b[${window.promptMessage.length + 1}G`);
						break;
					case String.fromCharCode(23):  // Ctrl+W: kill the word behind point
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
						// DID NOT CUT?? What is my selection? 
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
		    // window.webkit.messageHandlers.aShell.postMessage('moveCursorPosition ' + x + ' ' + y);
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
			var newCursorPosition = currentCommandCursorPosition - deltaCursor; 
			if (deltaCursor > 0) { 
				var string = io.currentCommand.slice(newCursorPosition, currentCommandCursorPosition);
				while (lib.wc.strWidth(string) > deltaCursor) {
					newCursorPosition += 1; 
					string = io.currentCommand.slice(newCursorPosition, currentCommandCursorPosition);
				}
			} else {
				var string = io.currentCommand.slice(currentCommandCursorPosition, newCursorPosition);
				while (lib.wc.strWidth(string) > -deltaCursor) {
					newCursorPosition -= 1; 
					string = io.currentCommand.slice(currentCommandCursorPosition, newCursorPosition);
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
		this.keyboard.characterEncoding = 'raw';
		// this.keyboard.bindings.addBinding('F11', 'PASS');
		// this.keyboard.bindings.addBinding('Ctrl-R', 'PASS');
	};
	term.decorate(document.querySelector('#terminal'));
	term.installKeyboard();
	window.term_ = term;
	// Useful for console debugging.
	console.log = println
	console.warn = window.webkit.messageHandlers.aShell.postMessage
	console.error = window.webkit.messageHandlers.aShell.postMessage
	if (window.commandRunning === undefined) {
		window.commandRunning = '';
	}
	window.interactiveCommandRunning = isInteractive(window.commandRunning);
	if (window.commandArray === undefined) {
		window.commandArray = new Array();
		window.commandIndex = 0;
		window.maxCommandIndex = 0;
	}
	if (window.printedContent === undefined) {
		window.printedContent = '';
	}
	if (window.printedContent == '') {
		printPrompt(); // first prompt
	}
	updatePromptPosition(); 
	window.commandInsideCommandArray = new Array();
	window.commandInsideCommandIndex = 0;
	window.maxCommandInsideCommandIndex = 0;
	window.promptMessage = "$ "; // prompt for commands, configurable
	window.promptEnd = 2; // prompt for commands, configurable
	window.promptLine = 0; // term line on which the prompt started
	window.promptScroll = 0; // scroll line on which the scrollPort was when the prompt started
	if (window.voiceOver != undefined) {
		window.term_.setAccessibilityEnabled(window.voiceOver);
	}
	if ((window.commandToExecute != undefined) && (window.commandToExecute != "")) {
		window.webkit.messageHandlers.aShell.postMessage('shell:' + window.commandToExecute);
		window.commandRunning = window.commandToExecute;
		window.commandToExecute = ""; 
	}
//  }, 3000);
};

// see https://github.com/holzschu/a-shell/issues/235
// This will be whatever normal entry/initialization point your project uses.
window.onload = async function() {
	await lib.init();
	setupHterm();
};

// Modifications and additions to hterm_all.js:
hterm.Terminal.IO.prototype.onTerminalResize = function(width, height) {
  // Override this.
  window.webkit.messageHandlers.aShell.postMessage('width:'  + width); 
  window.webkit.messageHandlers.aShell.postMessage('height:'  + height); 
};

hterm.Frame.prototype.postMessage = function(name, argv) {
  window.webkit.messageHandlers.aShell.postMessage('JS Error:' + ' hterm.Frame.prototype.postMessage.\n');	
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

  this.updateCssCharsize_();

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
      // Throw away existing touches that we're finished with.
      for (i = 0; i < e.changedTouches.length; ++i) {
        delete this.lastTouch_[e.changedTouches[i].identifier];
      }
      break;

    case 'touchmove': {
  	  e.preventDefault(); // iOS: prevent WKWebView from scrolling too.
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
	if (!this.useDefaultWindowCopy) {
		e.preventDefault();
		setTimeout(this.copySelectionToClipboard.bind(this), 0);
	}
	// iOS: clear selection after copy
	if (this.clearSelectionAfterCopy) {
		var selection = this.getDocument().getSelection();
		setTimeout(selection.collapseToEnd.bind(selection), 50);
	}  	
};

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
  	// But only for primary screen:
  	if (this.isPrimaryScreen()) { 
      window.webkit.messageHandlers.aShell.postMessage('Reprint everything');
      window.webkit.messageHandlers.aShell.postMessage('JS Error: Reprint everything: \n' + window.printedContent);
	  if (window.printedContent !== undefined) {
	  	let content = window.printedContent; 
	  	window.term_.wipeContents(); 
	  	window.printedContent = '';
	  	this.io.print(content);
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

  this.terminal_.interpret(string);
  // iOS: keep a copy of everything that has been sent to the screen, 
  // to restore terminal status later and resize.
  if (this.terminal_.isPrimaryScreen()) {
     window.printedContent += string;
  }
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
  if (parseState.args[0] == 5) {
    this.terminal.io.sendString('\x1b0n');
  } else if (parseState.args[0] == 6) {
	// window.webkit.messageHandlers.aShell.postMessage('CPR request (n)');
	window.interactiveCommandRunning = true;
    const row = this.terminal.getCursorRow() + 1;
    const col = this.terminal.getCursorColumn() + 1;
    this.terminal.io.sendString('\x1b[' + row + ';' + col + 'R');
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
  if (parseState.args[0] == 6) {
	// window.webkit.messageHandlers.aShell.postMessage('CPR request (?n)');
	window.interactiveCommandRunning = true;
    const row = this.terminal.getCursorRow() + 1;
    const col = this.terminal.getCursorColumn() + 1;
    this.terminal.io.sendString('\x1b[' + row + ';' + col + 'R');
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
 * Synchronizes the visible cursor with the current cursor coordinates.
 *
 * The sync will happen asynchronously, soon after the call stack winds down.
 * Multiple calls will be coalesced into a single sync. This should be called
 * prior to the cursor actually changing position.
 */
hterm.Terminal.prototype.scheduleSyncCursorPosition_ = function() {
  if (this.timeouts_.syncCursor) {
    return;
  }

  if (this.accessibilityReader_ != null) {
    if (this.accessibilityReader_.accessibilityEnabled) {
      // Report the previous position of the cursor for accessibility purposes.
      const cursorRowIndex = this.scrollbackRows_.length +
          this.screen_.cursorPosition.row;
      const cursorColumnIndex = this.screen_.cursorPosition.column;
      const cursorLineText =
          this.screen_.rowsArray[this.screen_.cursorPosition.row].innerText;
      this.accessibilityReader_.beforeCursorChange(
          cursorLineText, cursorRowIndex, cursorColumnIndex);
    }
  }

  this.timeouts_.syncCursor = setTimeout(() => {
    this.syncCursorPosition_();
    delete this.timeouts_.syncCursor;
  });
};

