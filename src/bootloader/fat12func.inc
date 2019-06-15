; This file is fat12 filesystem function to read data



; function_name readOneSector
; description: to read one sector data into buffer
; args: ax sectorNo
;       cl number of sector to read
;       es:bx -- buffer pointer

Func_ReadOneSector:

        push  bp
        mov   bp, sp
        sub   esp, 2
        mov   byte[bp - 2], cl
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


; function_name: getFatEntry
; description:   liner scan fat12 entry to 
; args:          ax - entry's sectorNo

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
    
    
  
    
