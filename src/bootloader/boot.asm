; bootloader run aat 0x7c00
org 0x7c00

; equ 命令会被编译器等价替换
; stack base
BaseOfStack   equ 0x7c00 
BaseOfLoader equ 0x1000
OffsetOfLoader  equ 0x0000



;FAT12 file system data structors

RootDirSectors            equ 14
SectorNumOfRootDirStart   equ 19
SectorNumOfFATStart       equ 1
SectorBalance             equ 17

jmp short Label_Start                 ; 调到代码开始处
nop                                   ; jmp调用占用两个字节,而fat12文件系统中起始偏移为4bit，需要设置nop偏移
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

;============ 程序相关代码和数据

StartBootMessage db "Start Boot"
LoaderFileName db "LOADER  BIN"
NoLoaderBinFoundMessage db "Loader_bin Not Found"
RootDirSizeForLoop dw 224 
SectorNo         dw 0
Odd               db 0


; start
Label_Start:
    mov ax, cs ; mov cs to ax  0x0000
    mov ds, ax 
    mov es, ax
    mov ss, ax
    mov sp, BaseOfStack

    ; =========clear screen
    ; ah = 0x06 Scrool the window in specify area
    ; al = 0x00 The line number to scroll, 0 to clean the screen
    ; bh = 0x07 
    mov ax, 0x0600
    mov bx, 0x0700
    mov cx, 0
    mov dx, 0x184f
    int 0x10 ; call the interuption of screen operation
    
    ; =========set focus
    ; ah = 0x02 set cursor foucus
    ; dh row number
    ; dl cow number
    ; bh page number
    mov ax, 0x0200
    mov bx, 0x0000
    mov dx, 0x0000
    int 0x10

    ; ====display on screen : Start Booting.....
    ; AH 0x13 Display a String Message
    ; AL write mode
    ; AL = 0x00 the base length of char is byte
    ; AL = 0x01 same as 0x00, but move the cursor to the end of String
    ; AL = 0x02 same as 0x00, but length of char is word
    ; AL = 0x03 same as 0x00, char length is word
    ; cx string length
    ; dh the number of line
    ; dl the number of row
    ; es:bp to calculate the string location
    ; bh page number
    ; bl char attribute/ char color
    mov ax, 0x1301
    mov bx, 0x000f
    mov dx, 0x0000
    mov cx, 10
    push ax
    mov ax, ds
    mov es, ax
    pop ax
    mov bp, StartBootMessage
    int 10h

    ; ====reset floppy
    ; interuption 0x13 reset the driver
    ; dl driver number
    ; 0x80 is the first hard driver
    ; 0x00 is the first floppy driver
    xor ah, ah
    xor dl, dl
    int 13h 

    jmp Label_Search_For_LoaderBins_Start ; while(1)


    ; file zero until whole sector
    ; $ means the machine code address
    ; $$ means the base address
    ; the sector length is 512 byte
    ; 

;=============      read one sector from floppy
;=============        arg0(ax): read the start sector number
;=============        arg1(cl): the number of the sectors to read
;=============        arg2(ES:BX): buffer address

Func_ReadOneSector:
    
    push        bp
    mov         bp,   sp
    sub         esp,  2                 ; create 2 byte space to save tthe sector number to read
    mov         byte [bp -2], cl        ; save the number of sectors to read
    push        bx
    mov         bl,   [BPB_SecPerTrk]
    div         bl                      
    inc         ah                      ; remainder is the sector number in this trunk
    mov         cl,   ah                ;
    mov         dh,   al                ; quotient  is the Magnetic head number
    shr         al,   1                 ; 
    mov         ch,   al
    and         dh,   1
    pop         bx
    mov         dl,   [BS_DrvNum]
Label_Go_On_Reading:
    mov         ah,   2                 ; int_13:
    mov         al,   byte  [bp -2]     ;     AL: num of sector to read         CH: trk_number's lower 8 bit
    int         13h                     ;     CL: 0-6 => num of the sector id , 6-7bit => the trk_number for hard disk
    jc          Label_Go_On_Reading     ;     DH: MagnetHeadNumber              DL: Driver Number
    add         esp,  2                 ; restore the stack
    pop         bp
    ret


;=============      search loader.bin
;=============

Label_Search_For_LoaderBins_Start:

    mov         word    [SectorNo],     SectorNumOfRootDirStart

Label_Search_In_Root_Dir_Begin:
    
    cmp         word    [RootDirSizeForLoop],     0   
    jz          Label_No_LoaderBin                      ; 如果root目录表项未找到loader.bin则跳出
    dec         word    [RootDirSizeForLoop]
    mov         ax,     00h                             
    mov         es,     ax                              ; 初始化es段寄存器
    mov         bx,     8000h                           ; 设置缓存内存区 0:8000h
    mov         ax,     [SectorNo]                      ; 待读入扇区的蔟号
    mov         cl,     1                               ; 读入一个扇区
    call        Func_ReadOneSector                      
    mov         si,     LoaderFileName                  ; 将文件名的位置放置在si寄存器中
    mov         di,     8000h                           ; 设置di为8000h
    cld
    mov         dx,     10h                             ; 一个扇区有16个表项(512/32 = 16)

Label_Search_For_LoaderBins:
    
    cmp         dx,     0                             
    jz          Label_Goto_Next_Sector_In_Root_Dir      ; 扇区到结尾未找到人和有用数据则读入下一个扇区
    dec         dx                                      
    mov         cx,     11                              ; 设置比较字符串的长度,在本系统中fat12表项文件名的长度为11bit

Label_Cmp_FileName:
    
    cmp         cx, 0
    jz          Label_FileName_Found                    ; 比较完毕则跳到文件已找到
    lodsb                                               ; 从ds:si(数据段)中读入一个字节到al中
    cmp         al,   byte[es:di]                       ; 比较缓冲区中的字节与待比较的字节是否相等
    jz          Label_Go_On                             ; 继续查找
    jmp         Label_Different

Label_Go_On:
    
    inc         di                                      ; 递增di指向缓存区中的下一个字节
    dec         cx
    jmp         Label_Cmp_FileName

Label_Different:
    and         di,   0xffe0                            ; 低九位清零
    add         di,   20h                               ; 将缓存去指针指向下一个区域
    mov         si,   LoaderFileName                    ; 重置si
    jmp         Label_Search_For_LoaderBins

Label_Goto_Next_Sector_In_Root_Dir:
    
    add         word [SectorNo],    1                 ; 增加扇区号
    jmp         Label_Search_In_Root_Dir_Begin



;==============  Loader.bin funded process

Label_No_LoaderBin:

    mov         ax, 0x1301
    mov         bx, 0x008c
    mov         dx, 0x0100
    mov         cx, 20
    push        ax
    mov         ax, ds
    mov         es, ax                                  ; 设置es段寄存器为ds段寄存器的值
    pop         ax
    mov         bp, NoLoaderBinFoundMessage             
    int         10h                                     ; 输出消息
    jmp         $


Label_FileName_Found:
    mov         ax, RootDirSectors                      ; 
    and         di, 0xffe0                              ; 低九位清零
    add         di, 0x1a                                ; 启始蔟号
    mov         cx, word [es:di]                        ; 加载缓冲区内容，获取启始蔟号
    push        cx
    add         cx, ax
    add         cx, SectorBalance
    mov         ax, BaseOfLoader
    mov         es, ax                                  ; 设置loader的段地址
    mov         bx, OffsetOfLoader                      ; 设置偏移
    mov         ax, cx

Label_Go_On_Loading_File:
    ;=====    打印加载情况
    push        ax
    push        bx
    mov         ah, 0eh
    mov         al, '.'
    mov         bl, 0fh
    int         10h
    pop         bx
    pop         ax
    ;=====

    mov         cl, 1
    call        Func_ReadOneSector                      ; 读取一个扇区 
    pop         ax
    call        Func_GetFatEntry                        ; 获取Fat表项
    cmp         ax, 0xfff                               ; 0xfff表示表项终结
    jz          Label_File_Loaded
    push        ax
    mov         dx, RootDirSectors
    add         ax, dx
    add         ax, SectorBalance
    add         bx, [BPB_BytePerSec]                    ; 读取一个扇区后，更改扇区偏移
    jmp         Label_Go_On_Loading_File

Label_File_Loaded:


    jmp       BaseOfLoader:OffsetOfLoader









;============   Get FatEntry
;============   ax: 表项的蔟号

Func_GetFatEntry:
    
    push        es                                      ; 压入缓冲区段寄存器
    push        bx

    push        ax
    mov         ax, 00
    mov         es, ax
    pop         ax                                      ; 获取
    mov         Byte [Odd], 0
    mov         bx, 3 
    mul         bx
    mov         bx, 2
    div         bx
    cmp         dx, 0                                   ; 余数是否为0
    jz          Label_Even
    mov         byte [Odd], 1

Label_Even:
    
    xor         dx, dx                                  ; 清楚余数
    mov         bx, [BPB_BytePerSec]
    div         bx                                      ; 当前字节数
    push        dx
    mov         bx, 8000h
    add         ax, SectorNumOfFATStart
    mov         cl, 2
    call        Func_ReadOneSector

    pop         dx
    add         bx, dx
    mov         ax, [es:bx]
    cmp         byte [Odd], 1
    jnz         Label_Even2
    shr         ax, 4

Label_Even2:
    
    and         ax, 0xfff                               ; 对于偶情况，截去头四个字节

    pop         bx
    pop         es
    ret

    times 510 - ($ - $$) db 0
    dw 0xaa55

