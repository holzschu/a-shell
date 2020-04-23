/// <reference types="node" />
export declare type TDataOut = string | Buffer;
export declare type TEncoding = 'ascii' | 'utf8' | 'utf16le' | 'ucs2' | 'base64' | 'latin1' | 'binary' | 'hex';
export declare type TEncodingExtended = TEncoding | 'buffer';
export declare const ENCODING_UTF8: TEncoding;
export declare function assertEncoding(encoding: string | undefined): void;
export declare function strToEncoding(str: string, encoding?: TEncodingExtended): TDataOut;
