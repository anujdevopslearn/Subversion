/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU Library or "Lesser" General Public      *
 *   License (LGPL) as published by the Free Software Foundation;          *
 *   either version 2 of the License, or (at your option) any later        *
 *   version.                                                              *
 *                                                                         *
 ***************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "ramp_base64.h"
#include "ramp.h"

#define SIZE_FILE        512
#define SCANTYPE_LENGTH 32

void READ_FILE(char *szXMLFile,
      int iScanNum);
void USAGE(char *argv0);


int main(int argc, char **argv)
{
   int iScanNum=0;
   char szXMLFile[SIZE_FILE];

   if (argc != 3)
   {
      printf("\n");
      printf(" USAGE:  %s [scan_num] [mzXML]\n\n", argv[0]);
      printf(" This program takes in a scan number and mzXML file and\n");
      printf(" simply prints various values from the scan header\n");
      printf("\n");
      printf(" Header information keys and meanings\n");
      printf("\tRT: retentionTime\n" );
      printf("\tACQ: acquisitionNum\n" ); 
      printf("\tMSLVL: msLevel\n" ); 
      printf("\tPEAKS: peaksCount\n" );
      printf("\tTIC: totIonCurrent\n" );
      printf("\tBMZ: basePeakMZ\n" );
      printf("\tBPI: basePeakIntensity\n" ); 
      printf("\tCE: collisionEnergy\n" ); 
      printf("\tIE: ionisationEnergy\n" ); 
      printf("\tLMZ: lowMZ\n" ); 
      printf("\tHMZ: highMZ\n" ); 
      printf("\tPSN: precursorScanNum\n" ); 
      printf("\tPMZ: precursorMZ\n" ); 
      printf("\tPCH: precursorCharge\n" ); 
      printf("\tPIN: precursorIntensity\n" ); 
      printf("\n");
      exit(1);
   }

   /*
    * Assign input scan # and mzXML file
    */
   sscanf(argv[1], "%d", &iScanNum);
   strcpy(szXMLFile, argv[2]);

   READ_FILE(szXMLFile, iScanNum);

   return(0);

} /*main*/


void READ_FILE(char *szXMLFile,
      int iScanNum)
{
   int  iAnalysisFirstScan,
        iAnalysisLastScan;
   struct ScanHeaderStruct scanHeader;
   RAMPFILE *pFI;
   RAMPREAL *pPeaks;
   

   ramp_fileoffset_t  indexOffset;
   ramp_fileoffset_t  *pScanIndex;

   if ( (pFI = rampOpenFile( szXMLFile )) == NULL)
   {
      printf("could not open input file %s\n", szXMLFile);
      exit(1);
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
      exit(1);
   }

   readHeader(pFI, pScanIndex[iScanNum], &scanHeader);
   double rTime=scanHeader.retentionTime;

   int seqNum = scanHeader.seqNum; // number in sequence observed file (1-based)
   int acquisitionNum = scanHeader.acquisitionNum; // scan number as declared in File (may be gaps)
   int  msLevel = scanHeader.msLevel;
   int  peaksCount = scanHeader.peaksCount;
   double totIonCurrent = scanHeader.totIonCurrent;
   double basePeakMZ = scanHeader.basePeakMZ;
   double basePeakIntensity = scanHeader.basePeakIntensity;
   double collisionEnergy = scanHeader.collisionEnergy;
   double ionisationEnergy = scanHeader.ionisationEnergy;
   double lowMZ = scanHeader.lowMZ;
   double highMZ = scanHeader.highMZ;
   int precursorScanNum = scanHeader.precursorScanNum; /* only if MS level > 1 */
   double precursorMZ = scanHeader.precursorMZ;  /* only if MS level > 1 */
   int precursorCharge = scanHeader.precursorCharge;  /* only if MS level > 1 */
   double precursorIntensity = scanHeader.precursorIntensity;  /* only if MS level > 1 */
//   char scanType[SCANTYPE_LENGTH] = scanHeader.scanType;
//   char activationMethod[SCANTYPE_LENGTH] = scanHeader.activationMethod;



   printf("RT:%0.1f\n", rTime );
   printf("ACQ:%u\n", acquisitionNum ); 
   printf("MSLVL:%u\n",  msLevel ); 
   printf("PEAKS:%u\n",  peaksCount );
   printf("TIC:%0.2f\n", totIonCurrent );
   printf("BMZ:%0.4f\n", basePeakMZ );
   printf("BPI:%0.2f\n", basePeakIntensity ); 
   printf("CE:%0.2f\n", collisionEnergy ); 
   printf("IE:%0.2f\n", ionisationEnergy ); 
   printf("LMZ:%0.2f\n", lowMZ ); 
   printf("HMZ:%0.2f\n", highMZ ); 
   printf("PSN:%u\n", precursorScanNum ); 
   printf("PMZ:%0.4f\n", precursorMZ ); 
   printf("PCH:%u\n", precursorCharge ); 
   printf("PIN:%0.2f\n", precursorIntensity ); 
   /*
   */



//      printf(" USAGE:  %s [scan_num] [mzXML]\n\n", argv[0]);
//      printf(" This program takes in a scan number and mzXML file and\n");

   
   rampCloseFile(pFI);

} /*READ_FILE*/
