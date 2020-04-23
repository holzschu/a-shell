declare const getBigIntHrtime: (nativeHrtime: Function) => (time?: [number, number] | undefined) => bigint;
export default getBigIntHrtime;
