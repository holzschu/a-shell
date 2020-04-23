import { Node } from "memfs/lib/node";

// Make emit synchronous
Node.prototype.emit = function(
  this: Node,
  event: string | symbol,
  ...args: any[]
): boolean {
  const listeners = this.listeners(event);
  for (let listener of listeners) {
    try {
      listener(...args);
    } catch (e) {
      console.error(e);
    }
  }
  return listeners.length > 0;
};
