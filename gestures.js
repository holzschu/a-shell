/**
 * Handles gesture recognition and inertial scrolling.
 */

function initializeTerminalGestures()
{
  const DEBUG = true;

  // Determines the decay rate of the inertial scroll
  // velocity.
  //   If 0.1, at the end of a second,
  //   the inertial scroll velocity is 1/10th of what it
  //   was at the beginning of the second.
  const INERTIAL_SCROLL_DECAY_FACTOR = 0.1;

  // Minimum lines/second for speed to trigger
  // inertial scrolling.
  const INERTIAL_SCROLL_MIN_INITIAL_SPEED = 10;

  // While inertial scrolling, if the inertial scroll speed
  // drops below this many lines per second, inertial scrolling
  // stops.
  const MIN_INERTIAL_SCROLL_CONTINUE_SPEED = 3;

  // When we start inertial scrolling, scroll this many times faster
  // than how fast we were scrolling with the user's finger/pointer
  // on the screen.
  const INITIAL_INERTIAL_SCROLL_VEL_MULTIPLIER = 1.5;

  // Minimum number of characters a cursor must move to trigger a
  //(non-arrow-)key press.
  const HORIZ_KEYBOARD_KEYPRESS_CHARS = 7;

  // Things that should only be done once: Useful for
  // debugging if we want to run this script multiple times
  // in the same instance of a-Shell.
  if (!window.gestures_)
  {
    window.gestures_ = {};
    window.gestures_.gestureStatus = document.createElement("div");

    term_.document_.body.appendChild(gestures_.gestureStatus);
    gestures_.gestureStatus.classList.add("gestureStatus");

    gestures_.gesturePtrDown = () => {};
    gestures_.gesturePtrMove = () => {};
    gestures_.gesturePtrUp = () => {};

    window.term_.document_.body.addEventListener('pointerdown', (evt) =>
      gestures_.gesturePtrDown(evt));
    window.term_.document_.body.addEventListener('pointermove', (evt) =>
      gestures_.gesturePtrMove(evt));
    window.term_.document_.body.addEventListener('pointerup', (evt) =>
      gestures_.gesturePtrUp(evt));
    window.term_.document_.body.addEventListener('keydown', (evt) =>
      gestures_.handleKeyEvent(evt));
  }

  let gestureStatus = gestures_.gestureStatus;

  // Style the debug output region.
  gestureStatus.style = `
      position: fixed;
      right: 0;
      bottom: 0;

      z-index: 999;
      max-width: 100px;

      box-shadow: 0px 0px 4px rgba(200, 100, 100, 0.6);

      border-top-left-radius: 5px;
      background-color: rgba(255, 255, 255, 0.9);
      padding: 3px;
      color: black;

      opacity: 0.5;
      display: none;

      font-family: monospace;
  `;

  // If we're not debugging, showDebugMsg shouldn't do anything.
  let showDebugMsg = () => {};

  // Debugging? Show the debug information window.
  if (DEBUG) {
    gestureStatus.style.display = "block";
    gestureStatus.innerText = "...";
    showDebugMsg = (text) => {
      gestureStatus.innerText = text;
    };
  }

  // Attempts to determine whether `less` or `man` are currently running.
  // Returns true if it thinks less or man is.
  const isLessRunning = () => {
    return window.commandRunning.search(new RegExp("(^less|^man|.*[|]\\s*less)")) == 0;
  };

  // Tries to determine whether the current command is vim.
  const isVimRunning = () => {
    return window.commandRunning.startsWith("vim");
  };

  const moveCursor = (dx, dy) => {
    for (let i = 0; i <= Math.abs(dx) - 1; i++) {
      term_.io.sendString(dx < 0 ? "\x1b[D" : "\033[C");
    }

    for (let i = 0; i <= Math.abs(dy) - 1; i++) {
      term_.io.sendString(dy > 0 ? "\x1b[B" : "\033[A");
    }
  };

  /// Returns the { width: px, height: px } size of a character in the terminal.
  const getCharSize = () => {
    return term_.scrollPort_.characterSize;
  };

  /// Tracks the velocity of a given
  //pointer.
  class VelocityTracker {
    constructor(ptrId) {
      this.targetId_ = ptrId;
      this.lastTime_ = (new Date()).getTime();
      this.lastPosition_ = null;
      this.velocity_ = [0, 0];
    }

    getVelocity() {
      return this.velocity_;
    }

    handleEvt(evt) {
      if (evt.pointerId != this.targetId_) {
        return;
      }

      const nowTime = (new Date()).getTime();
      let velocity = this.velocity_;

      if (this.lastPosition_) {
        const dx = (evt.pageX - this.lastPosition_[0]) / getCharSize().width;
        const dy = (evt.pageY - this.lastPosition_[1]) / getCharSize().height;
        const dt = (nowTime - this.lastTime_) / 1000;

        // Average the current estimated
        // velocity and the last for
        // smoother changes in velocity.
        velocity[0] += dx / dt;
        velocity[1] += dy / dt;
        velocity[0] /= 2;
        velocity[1] /= 2;
      }

      this.lastTime_ = nowTime;
      this.lastPosition_ = [ evt.pageX, evt.pageY ];
    }
  }

  class Gesture {
    constructor() {
      // Last positions at which pointer
      // data was eaten by an action.
      this.ptrLastHandledPositions_ = {};
      // VelocityTrackers for pointers
      this.ptrVelocities_ = {};
      // Set of pointer IDs that are currently
      // 'down'.
      this.ptrsDown_ = {};
      this.ptrCount_ = 0;

      // Number of unhandled characters in x and y directions
      // by this.
      this.bufferedDx_ = 0;
      this.bufferedDy_ = 0;

      // The gesture hasn't caused scrolling.
      this.isScrollGesture_ = false;

      // Maximum value of ptrsDown_
      // during this gesture.
      this.maxPtrCount_ = 0;
    }

    getPtrDownCount() {
      return this.ptrCount_;
    }

    onPointerDown(evt) {
      const ptrId = evt.pointerId;

      // Do nothing if we're already tracking
      // the pointer.
      if (this.ptrsDown_[ptrId] != undefined) {
        return;
      }

      this.ptrCount_++;
      this.maxPtrCount_ = Math.max(this.ptrCount_, this.maxPtrCount_);

      const velocityTracker = new VelocityTracker(ptrId);
      velocityTracker.handleEvt(evt);

      this.ptrLastHandledPositions_[ptrId] = [ evt.pageX, evt.pageY ];
      this.ptrVelocities_[ptrId] = velocityTracker;
      this.ptrsDown_[ptrId] = true;
    }

    onPointerMove(evt) {
      const charWidth = getCharSize().width;
      const charHeight = getCharSize().height;
      const ptrId = evt.pointerId;

      // Don't handle pointers that aren't down (e.g. mouse
      // cursors).
      if (!this.ptrsDown_[ptrId]) {
        return;
      }

      // Use this event to update the tracked velocity.
      this.ptrVelocities_[ptrId].handleEvt(evt);

      let lastPos = this.ptrLastHandledPositions_[ptrId];

      let dx = (evt.pageX - lastPos[0]) / charWidth;
      let dy = (evt.pageY - lastPos[1]) / charHeight;
      this.bufferedDx_ += dx / this.ptrCount_;
      this.bufferedDy_ += dy / this.ptrCount_;

      // Only act on the input when we've moved at least
      // a character in either x or y (so that we have enough input to act on.
      if (!this.shouldBufferDx_(this.bufferedDx_)) {
        showDebugMsg("Horiz:" + dx);

        this.handleHorizontal_(this.bufferedDx_, evt);
        this.bufferedDx_ = 0;
      }

      if (!this.shouldBufferDy_(this.bufferedDy_)) {
        showDebugMsg("Vert:" + dy);

        this.handleVertical_(this.bufferedDy_, evt);
        this.bufferedDy_ = 0;
      }

      lastPos[0] = evt.pageX;
      lastPos[1] = evt.pageY;
    }

    onPointerUp(evt, startInertialScroll) {
      const ptrId = evt.pointerId;

      // If the pointer isn't down, discard
      // the event.
      if (!this.ptrsDown_[ptrId]) {
        return;
      }

      const velocityTracker = this.ptrVelocities_[ptrId];

      this.ptrCount_ --;
      this.ptrsDown_[ptrId] = false;
      velocityTracker.handleEvt(evt);

      const velocity = velocityTracker.getVelocity();
      const vx = velocity[0];
      const vy = velocity[1];

      if (this.ptrCount_ == 0
          && this.isScrollGesture_
          && Math.abs(vy) >= INERTIAL_SCROLL_MIN_INITIAL_SPEED) {
        startInertialScroll(this, vx * INITIAL_INERTIAL_SCROLL_VEL_MULTIPLIER, vy * INITIAL_INERTIAL_SCROLL_VEL_MULTIPLIER);
      }
    }

    /// Handle inertial scrolling.
    ///  [dx] and [dy] both have units of
    /// characters and must have magnitude
    /// at least one.
    onInertialScrollUpdate(dx, dy) {
      //this.bufferedDx_ += dx; // Don't inertial scroll with horizontal gestures.
      this.bufferedDy_ += dy;

      if (!this.shouldBufferDy_(this.bufferedDy_)) {
        this.handleVertical_(this.bufferedDy_);
        this.bufferedDy_ = 0;
      }
    }

    /// Returns true iff we should keep
    /// inertial scrolling if the current
    /// inertial scroll velocity is
    /// [vx, vy] in characters.
    shouldKeepInertialScrolling(vx, vy) {
      return Math.abs(vy) >= MIN_INERTIAL_SCROLL_CONTINUE_SPEED;
    }

    // Returns true if the given [dx] shouldn't
    // be handled, but rather, buffered.
    shouldBufferDx_(dx) {
      if (this.maxPtrCount_ > 1) {
        return Math.abs(dx) < HORIZ_KEYBOARD_KEYPRESS_CHARS;
      }

      return Math.abs(dx) < 1;
    }

    // Returns true if the given dy should be buffered,
    // rather than handled.
    shouldBufferDy_(dy) {
      return Math.abs(dy) < 1;
    }

    /// [dx] is in units of characters
    /// and must have magnitude \geq 1
    handleHorizontal_(dx) {
      if (this.maxPtrCount_ >= 2) {
        // Stop scrolling, start keyboard gestures.
        this.isKeyboardGesture_ = true;
        this.isScrollGesture_ = false;

        if (dx >= HORIZ_KEYBOARD_KEYPRESS_CHARS) {
          term_.io.sendString("\t");
        } else if (dx <= -HORIZ_KEYBOARD_KEYPRESS_CHARS) {
          term_.io.sendString("\x1b");
        }
      } else if (!isLessRunning()) {
        // Horizontal gestures: Don't move cursor if in `man'
        moveCursor(dx, 0);
      }

      return this;
    }

    /// [dy] is in units of characters
    /// and must have magnitude \geq 1.
    handleVertical_(dy) {
      // Don't do built-in touch scrolling.
      term_.scrollPort_.onTouch = (e) => { e.preventDefault(); };
      this.isScrollGesture_ = true;

      // We count arrow key gestures as ``scroll gestures''.
      if (this.isKeyboardGesture_) {
        this.isScrollGesture_ = false;
        return;
      }

      // Vertical gestures: Move cursor if in vim/less/man
      if (window.interactiveCommandRunning && (isVimRunning() || isLessRunning()) || this.maxPtrCount_ == 2) {
        moveCursor(0, dy);
        term_.scrollEnd();
      } else {
        // Otherwise, scroll.
        for (let i = 1; i <= Math.abs(dy); i++) {
          if (dy > 0) {
            term_.scrollLineUp();
          } else {
            term_.scrollLineDown();
          }
        }
      }

      return this;
    };
  }


  // Inertial scroll state.
  let momentum = [0, 0];
  let momentumLoopRunning = false;

  // Start inertial scrolling with the initial velocity
  // <vx, vy>. At present, vx is unused.
  const startInertialScroll = (gesture, vx, vy) => {
    let momentumLoop;
    let lastT = (new Date()).getTime();
    let unhandledP = [ 0, 0 ];

    // Updates the "momentum" of the viewport in a loop.
    momentumLoop = () => {
      const p = momentum;
      const nowT = (new Date()).getTime();
      const dt = (nowT - lastT) / 1000.0;
      const decay = Math.pow(INERTIAL_SCROLL_DECAY_FACTOR, dt);

      showDebugMsg("P: <" + p[0] + ", " + p[1] + ">");

      p[0] *= decay;
      p[1] *= decay;

      unhandledP[0] += p[0] * dt;
      unhandledP[1] += p[1] * dt;

      // If we're still scrolling fast enough, continue
      // updating the momentum
      if (gesture.shouldKeepInertialScrolling(p[0], p[1])) {

        // Take action on any unhandled momentum
        if (Math.abs(unhandledP[1]) > 1) {
          // At present, not tracking p[0].
          gesture.onInertialScrollUpdate(0, unhandledP[1]);
          unhandledP[1] = 0;
        }

        momentumLoopRunning = true;
        lastT = nowT;
        requestAnimationFrame(momentumLoop);
      } else {
        momentumLoopRunning = false;
      }
    };

    momentum = [vx, vy];
    if (!momentumLoopRunning) {
      momentumLoop();
    }
  };

  // Saves the terminal's onTouch function
  // so we can use it to stop the terminal's
  // default touchscreen scrolling.
  let origTermTouchFn;
  let currentGesture;

  gestures_.gesturePtrDown = (evt) => {
    showDebugMsg("Down@" + evt.pageX + "," + evt.pageY);
    if (!currentGesture) {
      origTermTouchFn = term_.scrollPort_.onTouch;
    }

    try
    {
      momentum = [ 0, 0 ];
      if (!currentGesture) {
        currentGesture = new Gesture();
      }

      currentGesture.onPointerDown(evt);
    }
    catch(e)
    {
      alert(e);
    }
  };

  gestures_.gesturePtrMove = (evt) => {
    // Currently being moved by the user: Make sure we aren't inertial
    // scrolling.
    momentum = [0, 0];

    try
    {
      currentGesture.onPointerMove(evt);
    }
    catch(e)
    {
      alert(e);
    }
  };

  gestures_.gesturePtrUp = (evt) => {
    showDebugMsg(" Up @" + evt.pageX + "," + evt.pageY);

    try
    {
      currentGesture.onPointerUp(evt, startInertialScroll);

      if (currentGesture.getPtrDownCount() == 0) {
        term_.scrollPort_.onTouch = origTermTouchFn;
        currentGesture = undefined;
      }
    } catch(e) {
      alert(e);
    }
  };

  // Stop inertial scrolling if the user presses a key:
  gestures_.handleKeyEvent = (evt) => {
    momentum = [0, 0];
  };
}

