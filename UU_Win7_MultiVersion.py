#!/usr/bin/env python3
"""Optional cross-platform reference for UU Win7 multi-version compatibility research.
Windows 7 users can instead run the bundled CMD/VBScript; no Python required.
"""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import struct
import sys

KNOWN = {
    'ef7112e173cdc6d74735c50292cf9750082ce351cdea60dc068fc2b60f3aa92e': ('archive', 'ORIGINAL'),
    '98e02310b355aa94feaa0b6b259260065221fb8db2080c097ce35f151e92c284': ('archive', 'V1'),
    'e3ddd6ca6c291874116a8373ac52801767b5448a3be06230c404c5e7afd2e0db': ('archive', 'V2'),
    '8f1390b33bf003c543eab575aea2299d84e25a753ceb92faba751953844ef10a': ('tested', 'ORIGINAL'),
    '97ab3d5803cc0dc4040f82f0b1c20a09b7d361824ad0faa7a0e35ece3692c1b3': ('tested', 'V1'),
    '23c5e9ab91d7a5eb4e4187cf1f384a62a2bab860af6458c1dbacf77ec21aebc2': ('tested', 'V2'),
    '8781857cc8d1b0a037853c2132b2982492002c2ae946bd82fd5ab4f2893ab1a3': ('recent-tested', 'ORIGINAL'),
    '0f7d8c4e4b304859f047ab5bd0ea82e4042b93de110ef783efed37ebdad87e4a': ('recent-tested', 'V1'),
    '8da352a0c057f2e38c5f21785dafe4e3cab6d284f32209220e2d17b3f48c8751': ('recent-tested', 'V2'),
}
MAIN_ANCHOR = bytes.fromhex('0F85E1000000498B4D18488B01FF90A0000000')
COMMON_ANCHOR = bytes.fromhex('84C07417837C2420067709750E837C2424027207B0014883C438C3')
TAIL = bytes.fromhex('4883C438C3')
MAIN = {'ORIGINAL': bytes.fromhex('84c0'), 'V1': bytes.fromhex('0c01'), 'V2': bytes.fromhex('0c01')}
COMMON = {'ORIGINAL': bytes.fromhex('32c0'), 'V1': bytes.fromhex('32c0'), 'V2': bytes.fromhex('b001')}


def digest(p):
    h = hashlib.sha256()
    with Path(p).open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def section_text(b):
    if b[:2] != b'MZ':
        raise ValueError('not a PE executable')
    pe = struct.unpack_from('<I', b, 0x3c)[0]
    if pe < 64 or pe > 1_048_576 or b[pe:pe+4] != b'PE\x00\x00':
        raise ValueError('invalid PE header')
    machine, sections = struct.unpack_from('<HH', b, pe+4)
    sz = struct.unpack_from('<H', b, pe+20)[0]
    magic = struct.unpack_from('<H', b, pe+24)[0]
    if machine != 0x8664 or magic != 0x20b or not (1 <= sections <= 32):
        raise ValueError('requires an AMD64 PE32+ executable')
    off = pe+24+sz
    for i in range(sections):
        pos = off+40*i
        name = b[pos:pos+8].split(b'\0', 1)[0]
        raw_size, ptr = struct.unpack_from('<II', b, pos+16)
        if name == b'.text':
            if raw_size < 1024 or ptr+raw_size > len(b):
                raise ValueError('invalid .text section')
            return ptr, ptr+raw_size
    raise ValueError('missing .text section')


def locations(b):
    st,en = section_text(b)
    c=b[st:en]
    main=[st+i-2 for i in iter_locations(c, MAIN_ANCHOR)]
    common=[st+i+len(COMMON_ANCHOR) for i in iter_locations(c, COMMON_ANCHOR)]
    if len(main)!=1 or len(common)!=1:
        return main,common,'UNSUPPORTED'
    m,g=main[0],common[0]
    if m<st or g+7>en or b[g+2:g+7] != TAIL:
        return main,common,'UNSUPPORTED'
    for state in ('ORIGINAL','V1','V2'):
        if b[m:m+2]==MAIN[state] and b[g:g+2]==COMMON[state]:
            return main,common,state
    return main,common,'UNSUPPORTED'


def iter_locations(b,needle):
    i=0
    while True:
        i=b.find(needle,i)
        if i<0: return
        yield i
        i+=1


def inspect(p):
    p=Path(p)
    b=p.read_bytes()
    main,common,state=locations(b)
    h=digest(p)
    name, known_state=KNOWN.get(h, ('unknown',None))
    if known_state is not None and known_state != state:
        raise ValueError('known checksum has mismatched instructions')
    return {'sha':h,'size':len(b),'main':main,'common':common,'state':state,
            'known':known_state is not None,'name':name}


def change_copy(src,dest, state, m,g):
    if dest.exists(): raise ValueError(f'temporary file exists: {dest}')
    shutil.copy2(src,dest)
    with dest.open('r+b') as f:
        f.seek(m);f.write(MAIN[state])
        f.seek(g);f.write(COMMON[state])
        f.flush();os.fsync(f.fileno())


def replace_checked(dst,stage,swap,expected):
    try:
        os.replace(dst, swap)
    except OSError as e:
        raise ValueError(f'cannot move EXE; close UU/x64dbg: {e}')
    try:
        os.replace(stage,dst)
    except OSError:
        os.replace(swap,dst)
        raise
    if digest(dst)!=expected:
        try:
            dst.unlink();os.replace(swap,dst)
        except OSError:
            raise RuntimeError(f'CRITICAL: manually restore {swap} to {dst}')
        raise ValueError('post-write hash mismatch; previous EXE restored')
    swap.unlink()


def check_backup(info,backup,tmp, current):
    bi=inspect(backup)
    if bi['state']!='ORIGINAL' or bi['main']!=info['main'] or bi['common']!=info['common'] or bi['size']!=info['size']:
        raise ValueError('backup not a verified original for this build')
    if info['state']=='ORIGINAL':
        if bi['sha']!=info['sha']: raise ValueError('backup hash differs from current original')
    else:
        change_copy(backup,tmp,info['state'],bi['main'][0],bi['common'][0])
        try:
            if digest(tmp)!=info['sha']:raise ValueError('backup cannot reproduce current patched EXE')
        finally:
            tmp.unlink(missing_ok=True)


def run(action,target,assume_yes=False):
    target=Path(target).resolve()
    if target.name.lower()!='gameviewer.exe':raise ValueError('target must be named GameViewer.exe')
    if not target.is_file():raise ValueError('target not found')
    backup=Path(str(target)+'.Win7Original.bak')
    stage=Path(str(target)+'.Win7V3Stage.tmp')
    swap=Path(str(target)+'.Win7V3Swap.tmp')
    rev=Path(str(target)+'.Win7V3Verify.tmp')
    if any(p.exists() for p in (stage,swap,rev)):
        raise ValueError('leftover v3 temp/swap file; inspect before retrying')
    info=inspect(target)
    print('Target:',target,'\nSize:',info['size'],'\nSHA256:',info['sha'],'\nState:',info['state'],
          '\nBuild:',info['name'],'\nMain signature:',[hex(x) for x in info['main']],
          '\nCommon signature:',[hex(x) for x in info['common']],
          '\nOriginal backup:',backup.exists())
    if action=='check': return
    if info['state']=='UNSUPPORTED': raise ValueError('unrecognized or nonunique signatures; refusing to modify')
    m,g=info['main'][0],info['common'][0]
    if action=='apply':
        if info['state']=='V2':
            print('Already patched');return
        if not info['known'] and not assume_yes:
            print('提示：当前文件哈希未登记，但两个代码特征均匹配；无法保证实际兼容性。')
            print('继续前会备份原版；修改后 EXE 的原始数字签名将失效。')
            answer = input('是否继续尝试修补？输入 Y 确认，其他任何输入取消 [y/N]：').strip().lower()
            if answer != 'y':
                raise ValueError('用户已取消，未修改目标文件')
        if backup.exists():
            check_backup(info,backup,rev,target)
        else:
            if info['state']=='V1':raise ValueError('v1 without a valid original backup cannot be upgraded')
            shutil.copy2(target,backup)
            if digest(backup)!=info['sha']:raise ValueError('backup verification failed')
        change_copy(target,stage,'V2',m,g)
        stageinfo=inspect(stage)
        if stageinfo['state']!='V2' or stageinfo['size']!=info['size'] or stageinfo['main']!=info['main'] or stageinfo['common']!=info['common']:
            raise ValueError('staged patch validation failed')
        if info['known'] and not stageinfo['known']:raise ValueError('known build expected checksum not matched')
        change_copy(stage,rev,info['state'],m,g)
        if digest(rev)!=info['sha']:raise ValueError('reverse validation failed')
        rev.unlink()
        replace_checked(target,stage,swap,stageinfo['sha'])
        print('SUCCESS: patched, original backup kept at',backup)
    else:
        if info['state']=='ORIGINAL':print('Already original');return
        if not backup.exists():raise ValueError('verified original backup missing')
        check_backup(info,backup,rev,target)
        shutil.copy2(backup,stage)
        expected=digest(backup)
        if digest(stage)!=expected:raise ValueError('staged restore checksum failed')
        replace_checked(target,stage,swap,expected)
        print('SUCCESS: restored byte-for-byte')


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('action',choices=('check','apply','restore'))
    parser.add_argument('exe')
    parser.add_argument('--assume-yes', action='store_true', help='unknown builds only; research users')
    args=parser.parse_args()
    try: run(args.action,args.exe,args.assume_yes)
    except (OSError,ValueError,RuntimeError) as e:
        print('ERROR:',e,file=sys.stderr);sys.exit(1)
