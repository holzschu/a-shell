import WasmFs from "./index";
// @ts-ignore
import tar from "tar-stream";
// @ts-ignore
import { inflate } from "pako/dist/pako_inflate.min.js";

export const dirname = (path: string) => {
  return path.replace(/\\/g, "/").replace(/\/[^\/]*$/, "");
};

export const extractContents = (
  wasmFs: WasmFs,
  binary: Uint8Array,
  to: string
): Promise<any> => {
  let volume = wasmFs.volume;
  return new Promise((resolve, reject) => {
    // We create the "to" directory, in case it doesn't exist
    (volume as any).mkdirpBase(to, 0o777);
    // We receive a tar.gz, we first need to uncompress it.
    let inflatedBinary = inflate(binary);
    // Now, we get the tar contents
    let extract = tar.extract();
    extract.on("entry", function(header: any, stream: any, next: any) {
      let fullname = `${to}/${header.name}`;
      const chunks: Array<Buffer> = [];

      stream.on("data", (chunk: any) => chunks.push(chunk));

      // header is the tar header
      // stream is the content body (might be an empty stream)
      // call next when you are done with this entry

      stream.on("end", function() {
        if (header.type === "file") {
          let contents = Buffer.concat(chunks);
          // console.log(fullname, contents);
          try {
            volume.writeFileSync(fullname, contents);
          } catch (e) {
            // The directory is not created yet
            let dir = dirname(fullname);
            (volume as any).mkdirpBase(dir, 0o777);
            volume.writeFileSync(fullname, contents);
          }
        } else if (header.type === "directory") {
          (volume as any).mkdirpBase(fullname, 0o777);
        }

        next(); // ready for next entry
      });

      stream.resume(); // just auto drain the stream
    });

    extract.on("finish", () => {
      resolve(extract);
    });
    extract.on("error", (err: any) => {
      reject(err);
    });
    extract.end(Buffer.from(inflatedBinary));
  });
};
