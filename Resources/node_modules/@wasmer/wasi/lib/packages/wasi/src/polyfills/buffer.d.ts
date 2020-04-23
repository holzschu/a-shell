/// <reference types="node" />
declare const isomorphicBuffer: {
    new (str: string, encoding?: string | undefined): Buffer;
    new (size: number): Buffer;
    new (array: Uint8Array): Buffer;
    new (arrayBuffer: ArrayBuffer | SharedArrayBuffer): Buffer;
    new (array: any[]): Buffer;
    new (buffer: Buffer): Buffer;
    prototype: Buffer;
    from(arrayBuffer: ArrayBuffer | SharedArrayBuffer, byteOffset?: number | undefined, length?: number | undefined): Buffer;
    from(data: any[]): Buffer;
    from(data: Uint8Array): Buffer;
    from(str: string, encoding?: string | undefined): Buffer;
    of(...items: number[]): Buffer;
    isBuffer(obj: any): obj is Buffer;
    isEncoding(encoding: string): boolean | undefined;
    byteLength(string: string | Uint8Array | ArrayBuffer | SharedArrayBuffer | Uint8ClampedArray | Uint16Array | Uint32Array | Int8Array | Int16Array | Int32Array | Float32Array | Float64Array | DataView, encoding?: string | undefined): number;
    concat(list: Uint8Array[], totalLength?: number | undefined): Buffer;
    compare(buf1: Uint8Array, buf2: Uint8Array): number;
    alloc(size: number, fill?: string | number | Buffer | undefined, encoding?: string | undefined): Buffer;
    allocUnsafe(size: number): Buffer;
    allocUnsafeSlow(size: number): Buffer;
    poolSize: number;
};
export default isomorphicBuffer;
