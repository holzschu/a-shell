/**
 * Handles gesture recognition and inertial scrolling.
 */

function initializeTerminalGestures()
{
  const DEBUG = false;

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

  const handleHorizontalGesture = (amount) => {
    // Horizontal gestures: Don't move cursor if in `man'
    if (!isLessRunning()) {
      moveCursor(amount, 0);
    }
  };

  const handleVerticalGesture = (amount, evt) => {
    // Don't do built-in touch scrolling.
    term_.scrollPort_.onTouch = (e) => { e.preventDefault(); };

    // Vertical gestures: Move cursor if in vim/less/man
    if (window.interactiveCommandRunning && (isVimRunning() || isLessRunning()) || evt && !evt.isPrimary) {
      moveCursor(0, amount);
      term_.scrollEnd();
    } else {
      // Otherwise, scroll.
      for (let i = 1; i <= Math.abs(amount); i++) {
        if (amount > 0) {
          term_.scrollLineUp();
        } else {
          term_.scrollLineDown();
        }
      }
    }
  };

  // Inertial scroll state.
  let momentum = [0, 0];
  let momentumLoopRunning = false;

  // Start inertial scrolling with the initial velocity
  // <vx, vy>. At present, vx is unused.
  const startInertialScroll = (vx, vy) => {
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
      if (Math.abs(p[1]) >= MIN_INERTIAL_SCROLL_CONTINUE_SPEED) {

        // Take action on any unhandled momentum
        if (Math.abs(unhandledP[1]) > 1) {
          handleVerticalGesture(unhandledP[1]);
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

  let ptrLastPositions = {};
  let ptrLastHandledPositions = {};
  let ptrVelocities = {};
  let ptrLastTimes = {};

  gestures_.gesturePtrDown = (evt) => {
    showDebugMsg("Down@" + evt.pageX + "," + evt.pageY);
    origTermTouchFn = term_.scrollPort_.onTouch;

    momentum = [ 0, 0 ];

    const nowTime = (new Date()).getTime();

    ptrLastPositions[evt.pointerId] = [evt.pageX, evt.pageY];
    ptrLastHandledPositions[evt.pointerId] = [evt.pageX, evt.pageY];
    ptrVelocities[evt.pointerId] = [0, 0];
    ptrLastTimes[evt.pointerId] = nowTime;
  };

  const updatePtrVelocity = (evt) => {
    const charWidth = term_.scrollPort_.characterSize.width;
    const charHeight = term_.scrollPort_.characterSize.height;

    const nowTime = (new Date()).getTime();
    const lastPos = ptrLastPositions[evt.pointerId];
    const lastTime = ptrLastTimes[evt.pointerId];

    const dx = ( evt.pageX - lastPos[0] ) / charWidth;
    const dy = ( evt.pageY - lastPos[1] ) / charHeight;
    const dt = (nowTime - lastTime) / 1000;

    // Average the current and previous velocities:
    // makes sudden changes in velocity have less of
    // an impact on recorded velocity.
    let velocity = ptrVelocities[evt.pointerId];
    velocity[0] += dx / dt;
    velocity[1] += dy / dt;
    velocity[0] /= 2;
    velocity[1] /= 2;

    ptrLastTimes[evt.pointerId] = nowTime;
    lastPos[0] = evt.pageX;
    lastPos[1] = evt.pageY;
  };

  gestures_.gesturePtrMove = (evt) => {
    const charWidth = term_.scrollPort_.characterSize.width;
    const lineHeight = term_.scrollPort_.characterSize.height;

    updatePtrVelocity(evt);

    let lastPos = ptrLastHandledPositions[evt.pointerId];

    let dx = (evt.pageX - lastPos[0]) / charWidth;
    let dy = (evt.pageY - lastPos[1]) / lineHeight;

    // If we've moved enough to trigger a horizontal gesture,
    if (Math.abs(dx) > 1) {
      showDebugMsg("Horiz:" + dx);

      handleHorizontalGesture(dx, evt);
      lastPos[0] = evt.pageX;
    }

    if (Math.abs(dy) > 1) {
      showDebugMsg("Vert:" + dy);

      handleVerticalGesture(dy, evt);
      lastPos[1] = evt.pageY;
    }
  };

  gestures_.gesturePtrUp = (evt) => {
    showDebugMsg(" Up @" + evt.pageX + "," + evt.pageY);
    term_.scrollPort_.onTouch = origTermTouchFn;

    updatePtrVelocity(evt);
    const vy = ptrVelocities[evt.pointerId][1];

    // Should we start inertial scrolling?
    if (Math.abs(vy) > INERTIAL_SCROLL_MIN_INITIAL_SPEED) {
      startInertialScroll(0, vy * INITIAL_INERTIAL_SCROLL_VEL_MULTIPLIER);
    }
  };

  // Stop inertial scrolling if the user presses a key:
  gestures_.handleKeyEvent = (evt) => {
    momentum = [0, 0];
  };
}

