import { IFs } from "memfs";
import { Volume, DirectoryJSON, TFilePath } from "memfs/lib/volume";
import "./node_sync_emit";
export default class WasmFsDefault {
    volume: Volume;
    fs: IFs;
    constructor();
    private _toJSON;
    toJSON(paths?: TFilePath | TFilePath[], json?: any, isRelative?: boolean): DirectoryJSON;
    fromJSONFixed(vol: Volume, json: DirectoryJSON): void;
    fromJSON(fsJson: any): void;
    getStdOut(): Promise<unknown>;
}
export declare const WasmFs: typeof WasmFsDefault;
export declare type WasmFs = WasmFsDefault;
