import {vol} from '../../../memfs/lib';
import patchRequire from '../patchRequire';
const {ufs} = require('../../../unionfs/lib');
import * as fs from 'fs';


vol.fromJSON({'/foo/bar.js': 'console.log("obi trice");'});
ufs
    .use(vol)
    .use(fs);


patchRequire(ufs);
require('/foo/bar.js');
