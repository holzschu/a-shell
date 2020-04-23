/// <reference types="node" />
import { Volume, TFilePath, TData, TMode, TFlags, TFlagsCopy, TSymlinkType, TTime, IOptions, IAppendFileOptions, IMkdirOptions, IReaddirOptions, IReadFileOptions, IRealpathOptions, IWriteFileOptions, IStatOptions } from './volume';
import Stats from './Stats';
import Dirent from './Dirent';
import { TDataOut } from './encoding';
export interface TFileHandleReadResult {
    bytesRead: number;
    buffer: Buffer | Uint8Array;
}
export interface TFileHandleWriteResult {
    bytesWritten: number;
    buffer: Buffer | Uint8Array;
}
export interface IFileHandle {
    fd: number;
    appendFile(data: TData, options?: IAppendFileOptions | string): Promise<void>;
    chmod(mode: TMode): Promise<void>;
    chown(uid: number, gid: number): Promise<void>;
    close(): Promise<void>;
    datasync(): Promise<void>;
    read(buffer: Buffer | Uint8Array, offset: number, length: number, position: number): Promise<TFileHandleReadResult>;
    readFile(options?: IReadFileOptions | string): Promise<TDataOut>;
    stat(options?: IStatOptions): Promise<Stats>;
    truncate(len?: number): Promise<void>;
    utimes(atime: TTime, mtime: TTime): Promise<void>;
    write(buffer: Buffer | Uint8Array, offset?: number, length?: number, position?: number): Promise<TFileHandleWriteResult>;
    writeFile(data: TData, options?: IWriteFileOptions): Promise<void>;
}
export declare type TFileHandle = TFilePath | IFileHandle;
export interface IPromisesAPI {
    FileHandle: any;
    access(path: TFilePath, mode?: number): Promise<void>;
    appendFile(path: TFileHandle, data: TData, options?: IAppendFileOptions | string): Promise<void>;
    chmod(path: TFilePath, mode: TMode): Promise<void>;
    chown(path: TFilePath, uid: number, gid: number): Promise<void>;
    copyFile(src: TFilePath, dest: TFilePath, flags?: TFlagsCopy): Promise<void>;
    lchmod(path: TFilePath, mode: TMode): Promise<void>;
    lchown(path: TFilePath, uid: number, gid: number): Promise<void>;
    link(existingPath: TFilePath, newPath: TFilePath): Promise<void>;
    lstat(path: TFilePath, options?: IStatOptions): Promise<Stats>;
    mkdir(path: TFilePath, options?: TMode | IMkdirOptions): Promise<void>;
    mkdtemp(prefix: string, options?: IOptions): Promise<TDataOut>;
    open(path: TFilePath, flags: TFlags, mode?: TMode): Promise<FileHandle>;
    readdir(path: TFilePath, options?: IReaddirOptions | string): Promise<TDataOut[] | Dirent[]>;
    readFile(id: TFileHandle, options?: IReadFileOptions | string): Promise<TDataOut>;
    readlink(path: TFilePath, options?: IOptions): Promise<TDataOut>;
    realpath(path: TFilePath, options?: IRealpathOptions | string): Promise<TDataOut>;
    rename(oldPath: TFilePath, newPath: TFilePath): Promise<void>;
    rmdir(path: TFilePath): Promise<void>;
    stat(path: TFilePath, options?: IStatOptions): Promise<Stats>;
    symlink(target: TFilePath, path: TFilePath, type?: TSymlinkType): Promise<void>;
    truncate(path: TFilePath, len?: number): Promise<void>;
    unlink(path: TFilePath): Promise<void>;
    utimes(path: TFilePath, atime: TTime, mtime: TTime): Promise<void>;
    writeFile(id: TFileHandle, data: TData, options?: IWriteFileOptions): Promise<void>;
}
export declare class FileHandle implements IFileHandle {
    private vol;
    fd: number;
    constructor(vol: Volume, fd: number);
    appendFile(data: TData, options?: IAppendFileOptions | string): Promise<void>;
    chmod(mode: TMode): Promise<void>;
    chown(uid: number, gid: number): Promise<void>;
    close(): Promise<void>;
    datasync(): Promise<void>;
    read(buffer: Buffer | Uint8Array, offset: number, length: number, position: number): Promise<TFileHandleReadResult>;
    readFile(options?: IReadFileOptions | string): Promise<TDataOut>;
    stat(options?: IStatOptions): Promise<Stats>;
    sync(): Promise<void>;
    truncate(len?: number): Promise<void>;
    utimes(atime: TTime, mtime: TTime): Promise<void>;
    write(buffer: Buffer | Uint8Array, offset?: number, length?: number, position?: number): Promise<TFileHandleWriteResult>;
    writeFile(data: TData, options?: IWriteFileOptions): Promise<void>;
}
export default function createPromisesApi(vol: Volume): null | IPromisesAPI;
