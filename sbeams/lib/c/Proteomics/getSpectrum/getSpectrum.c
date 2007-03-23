/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU Library or "Lesser" General Public      *
 *   License (LGPL) as published by the Free Software Foundation;          *
 *   either version 2 of the License, or (at your option) any later        *
 *   version.                                                              *
 *                                                                         *
 ***************************************************************************/

/*** 
   Requires:  base64.c base64.h ramp.c ramp.h from http://sourceforge.net/projects/sashimi/trans_proteomic_pipeline/src/Parsers/ramp
****/ 


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "ramp.h"

#define SIZE_FILE        512

void READ_FILE(char *szXMLFile,
      int iScanNum);
void USAGE(char *argv0);


int main(int argc, char **argv)
{
   int iScanNum=0;
   char szXMLFile[SIZE_FILE];

   if (argc != 3)
   {
      fprintf(stderr, "USAGE:  %s [num] [mzXML]\n", argv[0]);
      exit(0);
   }
   else
   {
      sscanf(argv[1], "%d", &iScanNum);
      strcpy(szXMLFile, argv[2]);
   }

   READ_FILE(szXMLFile, iScanNum);

   return(1);

} /*main*/


void READ_FILE(char *szXMLFile,
      int iScanNum)
{
   int  iAnalysisFirstScan,
        iAnalysisLastScan;
   struct ScanHeaderStruct scanHeader;
   RAMPFILE  *pFI;
   RAMPREAL *pPeaks;
   

   ramp_fileoffset_t  indexOffset;
   ramp_fileoffset_t  *pScanIndex;

   if ( (pFI = rampOpenFile( szXMLFile )) == NULL)
   {
      printf("could not open input file %s\n", szXMLFile);
      exit(0);
   }

   /*
    * Read the offset of the index 
    */
   indexOffset = getIndexOffset( pFI );
   
   /*
    * Read the scan index into a vector, get LastScan
    */
   pScanIndex = readIndex( pFI , indexOffset, &iAnalysisLastScan );
   iAnalysisFirstScan = 1;

   if (iScanNum<iAnalysisFirstScan || iScanNum>iAnalysisLastScan)
   {
      printf("scan number %d outside of acceptable range (%d - %d)\n", iScanNum, iAnalysisFirstScan, iAnalysisLastScan);
      exit(0);
   }

   readHeader(pFI, pScanIndex[iScanNum], &scanHeader);
   
   if (scanHeader.peaksCount>0)
   {
      int iloop;
      int n=0;

      /*
       * read scan peaks
       */
      pPeaks = readPeaks( pFI, pScanIndex[iScanNum]);
      for (iloop=scanHeader.peaksCount; iloop-->0; )
      {
         double fMass=pPeaks[n++];
         double fInten=pPeaks[n++];
                 
         printf("%0.6f  %0.6f\n", fMass, fInten);
      }
      free(pPeaks);
   }
   else
      printf("0.0 0.0\n"); /* always print out one data point */

   rampCloseFile(pFI);

} /*READ_FILE*/


void USAGE(char *argv0)
{
   printf(" USAGE:\n");
   printf("         %s [scanNumber] [mzXML] \n", argv0);
   printf("\n");
   printf("    e.g. %s 1275 /data2/LT301.mzXML\n", argv0);
   printf("    This will print scan 1275 to standard out.\n");
   printf("\n");

   exit(EXIT_FAILURE);
} /*USAGE*/
