"""Pure synthetic PE fixture tests. NO vendor binaries are distributed."""
import struct
import unittest
from pathlib import Path
import importlib.util

PATH = Path(__file__).resolve().parents[1] / 'UU_Win7_MultiVersion.py'
spec = importlib.util.spec_from_file_location('uu_compat', PATH)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def fake_pe(state='ORIGINAL', duplicate=False):
    data = bytearray(0x2400)
    data[:2] = b'MZ'
    struct.pack_into('<I', data, 0x3c, 0x80)
    data[0x80:0x84] = b'PE\0\0'
    struct.pack_into('<H', data, 0x84, 0x8664)
    struct.pack_into('<H', data, 0x86, 1)
    struct.pack_into('<H', data, 0x94, 0xf0)
    struct.pack_into('<H', data, 0x98, 0x20b)
    sec = 0x80+24+0xf0
    data[sec:sec+8] = b'.text\0\0\0'
    struct.pack_into('<II', data, sec+16, 0x1000, 0x400)
    m,g = 0x480,0x750
    data[m:m+2] = module.MAIN[state]
    data[m+2:m+2+len(module.MAIN_ANCHOR)] = module.MAIN_ANCHOR
    data[g-len(module.COMMON_ANCHOR):g] = module.COMMON_ANCHOR
    data[g:g+2] = module.COMMON[state]
    data[g+2:g+7] = module.TAIL
    if duplicate:
        data[0x900:0x900+len(module.MAIN_ANCHOR)] = module.MAIN_ANCHOR
    return bytes(data),m,g


class LocationTests(unittest.TestCase):
    def test_three_states(self):
        for state in ('ORIGINAL','V1','V2'):
            with self.subTest(state=state):
                data,m,g=fake_pe(state)
                a,b,status=module.locations(data)
                self.assertEqual((a,b,status),([m],[g],state))

    def test_ambiguous_pattern_rejected(self):
        data,_,_=fake_pe('ORIGINAL', duplicate=True)
        _,_,state=module.locations(data)
        self.assertEqual(state,'UNSUPPORTED')

    def test_missing_pe_rejected(self):
        with self.assertRaises(ValueError):
            module.locations(b'not a PE')


if __name__=='__main__':
    unittest.main()
