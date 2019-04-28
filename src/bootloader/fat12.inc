;======== FAT12文件系统结构

BS_OEMNAME      db    "MINEboot"
BPB_BytePerSec  dw    512
BPB_SecPerClus  db    1
BPB_RsvSecCnt   dw    1
BPB_NumFATs     db    2
BPB_RootEntCnt  dw    224
BPB_TotSec16    dw    2880
BPB_Media       db    0xf0
BPB_FATSz16     dw    9
BPB_SecPerTrk   dw    18
BPB_NumHeads    dw    2
BPB_hiddSec     dd    0
BOB_TOtSec32    dd    0
BS_DrvNum       db    0
BS_Reservedl    db    0
BS_BootSig      db    0x29
BS_VolID        dd    0
BS_VolLab       db    "boot loader"
BS_FileSysType  db    "FAT12   "


;========= 临时数据
RootDirSectors          equ   14
RootDirSizeForLoop      equ   BPB_RootEntCnt
SectorNo                equ   0
SectorNumOfRootDirStart equ   19
SectorBalance           equ   17
SectorNumOfFATStart     equ   1

