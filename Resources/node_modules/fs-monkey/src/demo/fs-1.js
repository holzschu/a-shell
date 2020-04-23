import {vol} from '../../../memfs/lib';
import {patchFs} from '../index';

vol.fromJSON({'/dir/foo': 'bar'});
patchFs(vol);
console.log(require('fs').readdirSync('/'));
