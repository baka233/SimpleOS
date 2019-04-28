#include <stdio.h>

int main(char argv[], int argc)
{
    if(argc != 2)
    {
        printf("Usage: %s ImageFile\n", argv[0]);
        return 1;
    }
    
    FILE *pImageFile = fopen(argv[1], "rb");

    if(pImageFile == NULL)
    {
        puts("Read image file failed!");
        return 1;
    }

    fseek(pImageFile, 0, SEEK_END);
    long lFileSize = ftell(pImageFile);
    printf("Image size: %ld\n", lFileSize);

    //alloc buffer
    unsigned char *pImageBuffer = (unsigned char*)malloc(lFileSize);

    if(pImageBuffer == NULL)
    {
        puts("Memorey alloc failed!");
        return 1;
    }

    //ser file pointer to the begining
    fseek(pImageFIle, 0, SEEK_SET);

    //read the whole image file into memory
    long lReadResult = fread(pImageBuffer, 1, lFileSize, pImageFile);

    printf("Read size: %ld\n", lReadResult);

    if(lReadResult != lFileSize)
    {
        puts("Read file error!");
        free(pImageBuffer);
        fclose(pImageFile);
        return 1;
    }

    fclose(pImageFile);

    //print FAT12 structure
    PrintImage(pImageBuffer);

    //seek files of root direcotory
    SeekRootDir(pImageBuffer);

    // file read buffer
    unsigned char outBuffer[2048];

    //read file 0
    DWORD filesize = ReadFile(pImageBuffer, &FileHeaders[0], outBuffer);

    printf("File size: %u, file content: \n%s", filesize, outBuffer);
}
