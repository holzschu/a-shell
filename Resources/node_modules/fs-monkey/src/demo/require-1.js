import {vol} from '../../../memfs/lib';
import patchRequire from '../patchRequire';


vol.fromJSON({'/foo/bar.js': 'console.log("obi trice");'});
patchRequire(vol);


require('/foo/bar');
