import patchFs from '../patchFs';

describe('patchFs', () => {
    it('should overwrite the .readFileSync method', () => {
        const vol = {
            readFileSync: () => 'foo',
        };
        const fs = {};
        patchFs(vol, fs);
        expect(typeof fs.readFileSync).toBe('function');
        expect(fs.readFileSync()).toBe('foo');
    });

    it('should copy constants', () => {
        const vol = {
            F_OK: 123,
        };
        const fs = {};
        patchFs(vol, fs);
        expect(fs.F_OK).toBe(vol.F_OK);
    });

    describe('unpatch()', () => {
        it('should return "unpatch" method', () => {
            const vol = {
                F_OK: 123,
            };
            const fs = {};

            expect(typeof patchFs(vol, fs)).toBe('function');
        });

        it('should restore the original fs', () => {
            const original = function () {};
            const vol = {
                writeFileSync: () => {},
            };
            const fs = {
                writeFileSync: original,
            };

            const unpatch = patchFs(vol, fs);

            expect(fs.writeFileSync).not.toBe(original);

            unpatch();

            expect(fs.writeFileSync).toBe(original);
        });
    });
});
