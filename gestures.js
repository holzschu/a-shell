/**
 * Handles gesture recognition and inertial scrolling.
 */

function initializeTerminalGestures() {
  const DEBUG = false;

  // Determines the decay rate of the inertial scroll
  // velocity.
  //   If 0.1, at the end of a second,
  //   the inertial scroll velocity is 1/10th of what it
  //   was at the beginning of the second.
  const INERTIAL_SCROLL_DECAY_FACTOR = 0.1;

  // Minimum lines/second for speed to trigger
  // inertial scrolling.
  const INERTIAL_SCROLL_MIN_INITIAL_SPEED = 15;

  // While inertial scrolling, if the inertial scroll speed
  // drops below this many lines per second, inertial scrolling
  // stops.
  const MIN_INERTIAL_SCROLL_CONTINUE_SPEED = 3;

  // Maximum number of lines/second we can scroll
  const MAX_INERTIAL_SCROLL_SPEED = 2000;

  // When we start inertial scrolling, scroll this many times faster
  // than how fast we were scrolling with the user's finger/pointer
  // on the screen.
  const INITIAL_INERTIAL_SCROLL_VEL_MULTIPLIER = 1.4;

  // Minimum number of characters a cursor must move to trigger a
  //(non-arrow-)key press.
  const HORIZ_KEYBOARD_KEYPRESS_CHARS = 7;

  // We don't know how long wheel gestures actually take, but we can
  // guess.
  const MOUSE_WHEEL_GESTURE_EST_D_TIME = 0.5;

  // Multiplies the number of lines by which mouse wheel gestures scroll.
  const MOUSE_WHEEL_SENSITIVITY = 2;

  // Maximum estimated mouse wheel gesture speed in lines/second.
  const MOUSE_WHEEL_GESTURE_MAX_SPEED = 60;

  // Discard wheel events that happen within this number of seconds after
  // the previous.
  const MIN_TIME_BETWEEN_WHEEL_GESTURES = 0.05;

  // Minimum number of lines a single mouse wheel gesture can scroll.
  const MOUSE_WHEEL_MIN_LINES = 1;

  // Things that should only be done once: Useful for
  // debugging if we want to run this script multiple times
  // in the same instance of a-Shell.
  if (!window.gestures_) {
    window.gestures_ = {};

    // User-settable preferences
    // Can be overridden after loading this script.
    gestures_.preferences = {
      swipeLeft: {
        // At present, one-finger swipes are always arrow keys
        2: '\x1b[1~', // Two-finger left swipe: HOME
        3: '\x1b', // Three-finger left swipe: ESC
      },
      swipeRight: {
        2: '\t', // Two-finger right swipe: tab
 // TODO: \n doesn't act as expected:
 //        3: '\n', // Three-finger right swipe: Enter
      },
    };

    // Debug view
    window.gestures_.gestureStatus = document.createElement("div");
    term_.document_.body.appendChild(gestures_.gestureStatus);
    gestures_.gestureStatus.classList.add("gestureStatus");

    // Events
    gestures_.gesturePtrDown = () => {};
    gestures_.gesturePtrMove = () => {};
    gestures_.gesturePtrUp = () => {};
    gestures_.gestureMouseWheel = () => {};

    const targetElem = window.term_.scrollPort_.screen_;

    targetElem.addEventListener('pointerdown', (evt) =>
      gestures_.gesturePtrDown(evt));
    targetElem.addEventListener('pointermove', (evt) =>
      gestures_.gesturePtrMove(evt));
    targetElem.addEventListener('pointerleave', (evt) =>
      gestures_.gesturePtrUp(evt));
    targetElem.addEventListener('pointerup', (evt) =>
      gestures_.gesturePtrUp(evt));

    window.term_.document_.body.addEventListener('keydown', (evt) =>
      gestures_.handleKeyEvent(evt));

    // Have listeners inside and outside the terminal iframe:
    // We want to intercept the wheel event.
    document.body.addEventListener('wheel', (evt) =>
      gestures_.gestureMouseWheel(evt));
    window.term_.document_.body.addEventListener('wheel', (evt) =>
      gestures_.gestureMouseWheel(evt));
  }
  gestures_.preferences = gestures_.preferences || {};
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
      window.webkit.messageHandlers.aShell.postMessage('showDebugMsg:' + text);
      gestureStatus.innerText = text;
    };
  }

  // Attempts to determine whether `less` or `man` are currently running.
  // Returns true if it thinks less or man is.
  const isLessRunning = () => {
    return window.commandRunning.search(new RegExp("(^less|^man|^perldoc|.*[|]\\s*less)")) == 0;
  };

  // Commands like less and vim generally use an alternate screen
  // to display content.
  const isUsingAlternateScreen = () => {
    return !term_.isPrimaryScreen();
  };

  const moveCursor = (dx, dy) => {
    let escPrefix = term_.keyboard.applicationCursor ? "\x1bO" : "\x1b[";
    for (let i = 0; i <= Math.abs(dx) - 1; i++) {
      term_.io.onVTKeystroke(dx < 0 ? escPrefix + "D" : escPrefix + "C");
    }

    for (let i = 0; i <= Math.abs(dy) - 1; i++) {
      term_.io.onVTKeystroke(dy > 0 ? escPrefix + "B" : escPrefix + "A");
    }
  };

  /// Returns the { width: px, height: px } size of a character in the terminal.
  const getCharSize = () => {
    return term_.scrollPort_.characterSize;
  };

  let origTouchFn = term_.scrollPort_.onTouch;
  let disableTouchFn = undefined;

  /// Temporarily turn off hterm's touch scrolling.
  /// Does nothing if touch scrolling has already been disabled
  /// by this method.
  const disableHtermTouchScrolling = () => {
    if (term_.scrollPort_.onTouch !== disableTouchFn) {
      origTouchFn = term_.scrollPort_.onTouch;

      term_.scrollPort_.onTouch = (evt) => {
        origTouchFn(evt);
        evt.preventDefault();
      };

      disableTouchFn = term_.scrollPort_.onTouch;
    }
  };

  const enableHtermTouchScrolling = () => {
    term_.scrollPort_.onTouch = origTouchFn;
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

        // Too small of a time difference -> inaccurate velocities.
        if (dt < 0.02) {
          return;
        }

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
    /// [carryoverMomentum]: Any inertial scroll momentum (with mass=1)
    /// remaining just before the start of this gesture. Copied during
    /// initialization.
    constructor(carryoverMomentum) {
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

      this.origMomentum_ = [carryoverMomentum[0], carryoverMomentum[1]];
      this.gestureStartTime_ = (new Date()).getTime();
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

      if (Math.abs(this.bufferedDy_) > 0.5) {
        showDebugMsg("Disabled hterm scrolling.");

        // hterm's built-in touch scrolling can take effect
        // after the user attemtpts to scroll less than a line.
        // Don't do built-in touch scrolling.
        disableHtermTouchScrolling();
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

      const nowTime = (new Date()).getTime();
      const dt = (nowTime - this.gestureStartTime_) / 1000;

      this.startInertialScroll_(vx, vy, dt, startInertialScroll);
    }

    /// Decide whether to start inertial scrolling.
    /// [vy] is the gesture's end velocity and [dt]
    /// is the time it took to complete the gesture.
    /// Returns true iff inertial scrolling was started.
    startInertialScroll_(vx, vy, dt, startInertialScroll) {
      if (this.ptrCount_ == 0
          && this.isScrollGesture_
          && Math.abs(vy) >= INERTIAL_SCROLL_MIN_INITIAL_SPEED) {
        let carryoverX = this.origMomentum_[0] * Math.pow( INERTIAL_SCROLL_DECAY_FACTOR, dt);
        let carryoverY = this.origMomentum_[1] * Math.pow(INERTIAL_SCROLL_DECAY_FACTOR, dt);

        if (Math.sign(carryoverX) != Math.sign(vx)) {
          carryoverX = 0;
        }

        if (Math.sign(carryoverY) != Math.sign(vy)) {
          carryoverY = 0;
        }

        startInertialScroll(this,
          vx * INITIAL_INERTIAL_SCROLL_VEL_MULTIPLIER + carryoverX,
          vy * INITIAL_INERTIAL_SCROLL_VEL_MULTIPLIER + carryoverY);
        return true;
      }

      return false;
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

        let key = null;

        if (dx >= HORIZ_KEYBOARD_KEYPRESS_CHARS) {
          key = gestures_.preferences.swipeRight[this.maxPtrCount_] || key;
        } else if (dx <= -HORIZ_KEYBOARD_KEYPRESS_CHARS) {
          key = gestures_.preferences.swipeLeft[this.maxPtrCount_] || key;
        }

        if (key) {
          term_.io.sendString(key);
        }

        term_.scrollEnd();
      } else if (!isLessRunning()) {
        // Horizontal gestures: Don't move cursor if in `man'
        moveCursor(dx, 0);
      }

      return this;
    }

    /// [dy] is in units of characters
    /// and must have magnitude \geq 1.
    handleVertical_(dy) {
      this.isScrollGesture_ = true;

      // We count arrow key gestures as ``scroll gestures''.
      if (this.isKeyboardGesture_) {
        this.isScrollGesture_ = false;
        return;
      }

      // Vertical gestures: Move cursor if in vim/less/man
      if (isUsingAlternateScreen() || this.maxPtrCount_ == 2) {
        // In less, cursor movement scrolls content,
        // so invert the cursor movement direction for
        // more natural scrolling.
        if (isLessRunning()) {
          moveCursor(0, -dy);
        } else {
          moveCursor(0, dy);
        }
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

    // Updates the "momentum" of the viewport in a loop.
    momentumLoop = () => {
      const p = momentum;
      const nowT = (new Date()).getTime();
      const dt = (nowT - lastT) / 1000.0;
      const decay = Math.pow(INERTIAL_SCROLL_DECAY_FACTOR, dt);

      showDebugMsg("P: <" + p[0] + ", " + p[1] + ">");

      p[0] *= decay;
      p[1] *= decay;

      // If we're still scrolling fast enough, continue
      // updating the momentum
      if (gesture.shouldKeepInertialScrolling(p[0], p[1])) {
        gesture.onInertialScrollUpdate(p[0] * dt, p[1] * dt);

        momentumLoopRunning = true;
        lastT = nowT;
        requestAnimationFrame(momentumLoop);
      } else {
        momentumLoopRunning = false;
      }
    };

    // Some programs stop working if too much input/second
    // is given.
    if (Math.abs(vy) > MAX_INERTIAL_SCROLL_SPEED) {
      vy = Math.sign(vy) * MAX_INERTIAL_SCROLL_SPEED;
    }

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

    // Only interpret touch events as gestures
    if (evt.pointerType != "touch") {
      return;
    }

    try {
      // If the user has selected something, exit. Let them continue
      // the selection.
      const selection = term_.document_.getSelection();
      if (!selection.isCollapsed) {
        return;
      }

      // If the start of a new gesture (we may have lost
      // the end of the previous):
      if (evt.isPrimary || !currentGesture) {
        currentGesture = new Gesture(momentum);
      }

      momentum = [ 0, 0 ];
      currentGesture.onPointerDown(evt);
    } catch(e) {
      if (DEBUG) {
        alert(e);
      }
    }
  };

  gestures_.gesturePtrMove = (evt) => {
    // Currently being moved by the user: Make sure we aren't inertial
    // scrolling.
    momentum = [0, 0];

    if (!currentGesture) {
      return;
    }

    evt.preventDefault();

    // Don't scroll the main window.
    document.scrollingElement.scrollTop = 0;

    try {
      currentGesture.onPointerMove(evt);
    } catch(e) {
      if (DEBUG) {
        alert(e);
      }
    }
  };

  gestures_.gesturePtrUp = (evt) => {
    showDebugMsg(" Up @" + evt.pageX + "," + evt.pageY);

    if (!currentGesture) {
      return;
    }

    try {
      currentGesture.onPointerUp(evt, startInertialScroll);

      if (currentGesture.getPtrDownCount() == 0) {
        currentGesture = undefined;
        enableHtermTouchScrolling();
      }
    } catch(e) {
      if (DEBUG) {
        alert(e);
      }
    }
  };

  let lastWheelTime = (new Date()).getTime();
  gestures_.gestureMouseWheel = (evt) => {
    evt.preventDefault();

    if (!currentGesture) {
      currentGesture = new Gesture(momentum);
      momentum = [ 0, 0 ];
    }

    const lineHeight = getCharSize().height;
    const nowTime = (new Date()).getTime();

    try {
      let dy = evt.deltaY;

      // Don't scroll the main window.
      document.scrollingElement.scrollTop = 0;

      // We don't really know how long the gesture took,
      // but let's guess:
      let dt = MOUSE_WHEEL_GESTURE_EST_D_TIME;
      let actualDt = (nowTime - lastWheelTime) / 1000;

      if (actualDt < MIN_TIME_BETWEEN_WHEEL_GESTURES) {
          return;
      }

      // If the actual time between this and the last scroll gestures
      // is less than our estimate, use the actual time as our estimate.
      if (actualDt < dt) {
        dt = actualDt;
      }

      // Scroll events deltaY can be specified in units other than
      // lines. See
      //  https://developer.mozilla.org/en-US/docs/Web/API/WheelEvent
      if (evt.deltaMode == WheelEvent.DOM_DELTA_PIXEL) {
        dy /= lineHeight;
      } else if (evt.deltaMode == WheelEvent.DOM_DELTA_PAGE) {
        dy *= term_.screenSize.height / MOUSE_WHEEL_SENSITIVITY;
      }

      dy *= MOUSE_WHEEL_SENSITIVITY;
      if (Math.abs(dy) < MOUSE_WHEEL_MIN_LINES) {
        dy = Math.sign(dy) * MOUSE_WHEEL_MIN_LINES;
      }

      showDebugMsg("Wheel: " + dy);
      currentGesture.handleVertical_(dy);

      // Estimate a velocity and try to start inertial scrolling.
      let estimatedVy = dy / dt;

      // Bound the estimated velocity.
      if (Math.abs(estimatedVy) > MOUSE_WHEEL_GESTURE_MAX_SPEED) {
        estimatedVy = Math.sign(estimatedVy) * MOUSE_WHEEL_GESTURE_MAX_SPEED;
      }

      currentGesture.startInertialScroll_(0, estimatedVy, dt, startInertialScroll);
      currentGesture = undefined;
    } catch(e) {
      if (DEBUG) {
        alert(e);
      }
    }

    lastWheelTime = nowTime;
  };

  // Stop inertial scrolling if the user presses a key:
  gestures_.handleKeyEvent = (evt) => {
    momentum = [0, 0];
  };
}
