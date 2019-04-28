org   10000h
    jmp   Label_Start

    %include "src/bootloader/fat12.inc"

    BaseOfKernelFile        equ     0x00
    OffsetOfKernelFile      equ     0x100000

    BaseTmpOfKernelAddr     equ     0x00
    OffsetTmpOfKernelFile   equ     0x7E00

    MemoryStructBufferAddr  equ     0x7E00

    OffsetOfKernelFileCount db      0

    Odd                     db      0

    ;TODO: 需要修改
    DisplayPosition         dd      0
;===== display Message
StartLoaderMessage        db    "Start Loader"
NoKernelBinFoundMessage   db    "Error: Kernel Bin Not Founded"
StartGetMemStructMessage  db    "start gettting memory struct address..."
KernelFileName            db    "KERNEL  BIN"
GetMemFailMessage         db    "Get memory struct failed"
GetMemFailMessageLen      equ   $ - GetMemFailMessage
GetMemOkMessage           db    "Get memory struct successful"
GetMemOkMessageLen        equ   $ - GetMemOkMessage
GO_TO_TMP_Protect         equ   0000

[SECTION .s16]
[BITS 16]

Label_Start:

    mov   ax, cs
    mov   ds, ax      ; ds段与cs段相同
    mov   es, ax
    mov   ax, 0x00
    mov   ss, ax      ; 设置ss段为0
    mov   sp, 0x7c00  ; 栈数据段位于 0x7c00:0段中

    mov   ax, 1301h
    mov   bx, 000fh
    mov   dx, 0200h
    mov   cx, 12
    push  ax
    mov   ax, ds
    mov   es, ax
    pop   ax
    mov   bp, StartLoaderMessage
    int   10h

;======  open address A20
;======  

    push ax
    in  al, 96h
    mov al, 00000010b
    out 92h, al
    pop ax

    cli                         ; 禁用外部中断

    db    0x66
    lgdt  [GdtPtr]              ; 加载gdt数据结构

    mov   eax,  cr0
    or    eax,  1
    mov   cr0, eax

    mov   ax, SelectorData32    ; 读取gdt
    mov   fs, ax
    mov   eax, cr0
    and   al, 11111110b         ; 将第零位置位
    mov   cr0, eax

    sti
    jmp $


;======= search kernel bin

Label_Search_For_KernelBin_Start:
    mov   word [SectorNo], SectorNumOfRootDirStart    ;
    
Label_Search_In_Root_Dir_Begin:
    
    cmp   word [RootDirSizeForLoop],  0
    jz    Label_No_KernelBin
    dec   word [RootDirSizeForLoop]

    mov   ax, 00h
    mov   es, ax                                      ; 设置es段到缓冲区
    mov   bx, 8000h
    mov   ax,   [SectorNo]
    mov   cl, 1
    call  Func_ReadOneSector
    mov   si, KernelFileName
    mov   di, 8000h
    cld
    mov   dx, 10h

Label_Search_For_KernelBin:

    cmp   dx, 0
    jz    Label_Goto_Next_Sector_In_Root_Dir
    dec   dx
    mov   cx, 11

Label_Cmp_FileName:
    
    cmp   cx, 0
    jz    Label_FileName_Found

    cmp   al, byte[es:di]
    jz    Label_Go_On
    jmp   Label_Different

Label_Go_On:
    
    dec   cx
    inc   di
    jmp   Label_Cmp_FileName

Label_Different:
    
    and   di, 0xffe0
    add   di, 0x20
    mov   si, KernelFileName
    jmp Label_Search_For_KernelBin

Label_Goto_Next_Sector_In_Root_Dir:
    add   word[SectorNo], 1
    jmp   Label_Search_In_Root_Dir_Begin
    

    call  Func_ReadOneSector

;========= Didn't find the Kernel File

Label_No_KernelBin:
    
    mov   ax, 0x1301
    mov   bx, 0x008c
    mov   dx, 0x0300
    mov  cx, 20
    push  ax
    mov   ax, ds
    mov   es, ax
    pop   ax
    mov   bp, NoKernelBinFoundMessage
    int   0x10
    jmp   $

;======== File Founded

Label_FileName_Found:
    mov   ax, RootDirSectors
    and   di, 0xffe0
    add   di, 0x1a                          ;获取起始蔟号
    mov   cx, word [es:di]
    push  cx                                ; 将蔟号亚压入栈中
    add   cx, ax
    add   cx, SectorBalance
    mov   eax, BaseTmpOfKernelAddr
    mov   es, eax
    mov   bx, OffsetTmpOfKernelFile
    mov   ax, cx

Label_Go_On_Loading_File:
    
    push  ax
    push  bx
    mov   ah, 0eh                           ; 调用0x0e的中断
    mov   al, '.'                           ; 打印.
    mov   bl, 0fh                           ; 黑色背景
    int   10h
    pop   bx
    pop   ax

    mov   cl, 1
    call  Func_ReadOneSector                ; 将扇区信息转移到临时空间

;;;;;;;;;;;;;  与boot.bin     不同一个字节一个字节的转存
    push  cx
    push  eax
    push  fs
    push  edi
    push  ds
    push  esi
    
    mov   cx, 200h                          ; 每个扇区长度0x200(512)Byte
    mov   ax, BaseTmpOfKernelAddr 
    mov   fs, ax
    mov   edi, dword  [OffsetOfKernelFileCount]

    mov   ax, BaseTmpOfKernelAddr
    mov   ds, ax
    mov   esi, OffsetTmpOfKernelFile

Label_Mov_Kernel:
    
    mov   al, byte [ds:esi]                 ; 将数据从临时存储空间读取到32bit位宽的空间
    mov   byte [fs:edi], al
    
    inc   esi
    inc   edi

    loop  Label_Mov_Kernel                  ; 循环执行知道cx为0

    mov   eax,  0x1000
    mov   ds, eax

    mov   dword [OffsetOfKernelFileCount], edi ; 将OffsetOfKernelFileCount 修改为当前edi的值

    pop   esi
    pop   ds
    pop   edi
    pop   fs
    pop   eax
    pop   cx



;;;;;;;;;;;;;
    pop   ax
    call  Func_GetFatEntry
    cmp   ax, 0xfff
    jz    Label_File_Loaded
    push  ax
    add   ax, BaseTmpOfKernelAddr
    add   ax, dx
    add   ax, SectorBalance
    add   bx, [BPB_BytePerSec]
    jmp   Label_Go_On_Loading_File

Label_File_Loaded:

    mov   ax, 0B800h
    mov   gs, ax
    mov   ah, 0fh
    mov   al, 'G'
    mov   [gs:((80*0 + 39)) *2], ax

KillMotor:                                ; 关闭软驱马达

    push  dx
    mov   dx, 0x3f2
    mov   al, 0                           ; 将0x3f2置位
    out   dx, al
    pop   dx

;===== GetMomoryAddr

Label_GetMemoryAddr:
    mov   ax, 1301h                       
    mov   bx, 000fh
    mov   dx, 0500h
    mov   bp, StartGetMemStructMessage
    int   10h

    mov   ebx, 0
    mov   ax, 0x00
    mov   es, ax
    mov   di, MemoryStructBufferAddr      ; 设定缓冲区

Label_Get_Mem_Struct:

    mov   eax, 0x0E820
    mov   ecx, 10
    mov   edx, 0x534D4150
    int   15h
    jc    Label_Get_Mem_Fail
    add   di, 20
    cmp   ebx, 0
    jne   Label_Get_Mem_Struct
    jmp   Label_Get_Mem_Ok

Label_Get_Mem_Fail:
    
    mov   ax, 0x1301
    mov   bx, 0x000f
    mov   dx, 0x0700
    mov   bp, [GetMemFailMessage]
    mov   cx, GetMemFailMessageLen
    int   10h

Label_Get_Mem_Ok:

    mov   ax, 0x1301
    mov   bx, 0x000f
    mov   bp, [GetMemOkMessage]
    mov   cx, GetMemOkMessageLen


    int   10h

[SECTION .s16lib]
[BITS 16]
; 显示数字

Func_Set_SVGA_mode:
    
    push  ax
    push  bx
    mov   ax, 0x4F02
    mov   bx, 0x4180
    int   10h
    pop   ax
    pop   bx
    ret

Func_GetFatEntry:

    push  es
    push  bx

    push  ax
    mov   ax,  0
    mov   es, ax
    pop   ax

    mov   bx, 3
    mul   bx
    mov   bx, 2
    div   bx
    mov   byte [Odd], 0
    
    cmp   dx, 0
    jz    Label_Even
    mov   byte [Odd], 1

Label_Even:
    
    xor   dx, dx
    mov   bx, [BPB_BytePerSec]
    div   bx
    push  dx
    mov   bx, 8000h
    mov   ax, SectorNumOfFATStart
    mov   cl, 2
    call  Func_ReadOneSector

    pop   dx
    add   bx, dx
    mov   ax, [es:bx]
    cmp   byte  [Odd], 1
    jnz   Label_Even2
    shr   ax, 4

Label_Even2:

    and   ax, 0xfff
    
    pop   bx
    pop   es
    ret


Label_DispAL:
    
    push  ecx
    push  edx
    push  edi

    mov   edi, dword [DisplayPosition]
    mov   ah, 0x0f
    mov   dl, al
    shr   al, 4
    mov   ecx, 2

.begin:
    
    and   al, 0fh
    cmp   al, 9
    ja    .1
    add   al, '0'
    jmp   .2

.1:
    sub   al, 0Ah
    add   al, 'A'

.2:
    mov   [gs:edi], ax
    add   edi, 2

    mov   al, dl
    loop  .begin
    mov   dword [DisplayPosition], edi

    pop   edi
    pop   edx
    pop   ecx
    ret

Func_ReadOneSector:

    push  bp
    mov   bp, sp
    sub   esp, 2
    mov   byte[bp - 1], cl
    push  bx
    mov   bl, [BPB_SecPerTrk]
    div   bl
    inc   ah
    mov   cl, ah
    mov   dh, al
    shr   al, 1
    mov   ch, al
    and   dh, 1
    pop   bx
    mov   dl, [BS_DrvNum]

Label_Go_On_Read_Sector:
    
    mov   ah, 2
    mov   al, byte [bp -2]
    int   13h
    jc    Label_Go_On_Read_Sector
    add   esp, 2
    pop   bp
    ret


[SECTION  .gdt]

LABEL_GDT            dd        0, 0
LABEL_DESC_CODE32    dd        0x0000FFFF, 0x00CF9A00
LABEL_DESC_DATA32    dd        0x0000FFFF, 0x00CF9200

GdtLen      equ   $ - LABEL_GDT
GdtPtr      dw    GdtLen - 1
            dd    LABEL_GDT

SelectorCode32        equ       LABEL_DESC_CODE32 - LABEL_GDT
SelectorData32        equ       LABEL_DESC_DATA32 - LABEL_GDT


;===== init IDT/GDT goto protect mode
    push  ax
    in    al, 92h
    or    al, 00000010b         ; 通过A20快速门来开启4GB地址寻址空间
    out   92h, al
    pop   ax


    cli ;========= 关闭中断

    db    0x66          ; 16bii 代码段要填充0x66来执行32位命令
    lgdt  [GdtPtr]

;    db    0x66
;    lidt  [IDT_POINTER]


    mov   eax, cr0
    or    eax, 1
    mov   cr0, eax

    sti

    jmp   dword SelectorCode32:GO_TO_TMP_Protect




