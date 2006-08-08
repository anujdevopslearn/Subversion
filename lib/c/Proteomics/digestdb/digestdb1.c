/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU Library or "Lesser" General Public      *
 *   License (LGPL) as published by the Free Software Foundation;          *
 *   either version 2 of the License, or (at your option) any later        *
 *   version.                                                              *
 *                                                                         *
 ***************************************************************************/

/*
 * Date:    11/05/2002
 * Copyright Jimmy Eng, Institute for Systems Biology
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MIN_PEPTIDE_MASS     200 
#define MAX_PEPTIDE_MASS     100000
#define ALLOWED_MISSED_CLEAVAGES 0

#define MAX_LEN_PEPTIDE      100
#define MAX_LEN_DEFINITION   100
#define INITIAL_SEQ_LEN      1000
#define SIZE_BUF             8192


double dMassAA[256];

struct ParamStruct
{
    int iMissedCleavage;   /* num allowed  missed cleavages */
   char szDb[256];
   char szBreakPoint[24];  /* which residues to fragment */
   char szNoBreakPoint[24];
} pInput;

static struct DbStruct
{
    int iLenSeq;
   char szDef[MAX_LEN_DEFINITION];
   char *szSeq;
} pSeq;

struct
{
   int iStart;
   int iEnd;
   double dPepMass;
} pPep;



void READ_FASTA(void);
void FIND_TRYPTIC_PEPTIDES();


void SET_AMINOACID_MASSES(double *pdMassAA,
        int iMassType)  /*0=avg, 1=mono */
{
   memset(dMassAA, 0, sizeof(dMassAA));

   if (!iMassType) /*avg masses*/
   {
      pdMassAA['h']=  1.00794;  /* hydrogen */
      pdMassAA['o']= 15.9994;   /* oxygen */
      pdMassAA['c']= 12.0107;   /* carbon */
      pdMassAA['n']= 14.00674;  /* nitrogen */
      pdMassAA['p']= 30.973761; /* phosporus */
      pdMassAA['s']= 32.066;    /* sulphur */

      pdMassAA['G']= 57.05192;
      pdMassAA['A']= 71.07880;
      pdMassAA['S']= 87.07820;
      pdMassAA['P']= 97.11668;
      pdMassAA['V']= 99.13256;
      pdMassAA['T']=101.10508;
      pdMassAA['C']=103.13880;
      pdMassAA['L']=113.15944;
      pdMassAA['I']=113.15944;
      pdMassAA['N']=114.10384;
      pdMassAA['O']=114.14720;
      pdMassAA['B']=114.59622;
      pdMassAA['D']=115.08860;
      pdMassAA['Q']=128.13072;
      pdMassAA['K']=128.17408;
      pdMassAA['Z']=128.62310;
      pdMassAA['E']=129.11548;
      pdMassAA['M']=131.19256;
      pdMassAA['H']=137.14108;
      pdMassAA['F']=147.17656;
      pdMassAA['R']=156.18748;
      pdMassAA['Y']=163.17596;
      pdMassAA['W']=186.21320;
      pdMassAA['X']=99999.99;
   }
   else /* monoisotopic masses */
   {
      pdMassAA['h']=  1.0078250;
      pdMassAA['o']= 15.9949146;
      pdMassAA['c']= 12.0000000;
      pdMassAA['n']= 14.0030740;
      pdMassAA['p']= 30.9737633;
      pdMassAA['s']= 31.9720718;

      pdMassAA['G']= 57.0214636;
      pdMassAA['A']= 71.0371136;
      pdMassAA['S']= 87.0320282;
      pdMassAA['P']= 97.0527636;
      pdMassAA['V']= 99.0684136;
      pdMassAA['T']=101.0476782;
      pdMassAA['C']=103.0091854;
      pdMassAA['L']=113.0840636;
      pdMassAA['I']=113.0840636;
      pdMassAA['N']=114.0429272;
      pdMassAA['O']=114.0793126;
      pdMassAA['B']=114.5349350;
      pdMassAA['D']=115.0269428;
      pdMassAA['Q']=128.0585772;
      pdMassAA['K']=128.0949626;
      pdMassAA['Z']=128.5505850;
      pdMassAA['E']=129.0425928;
      pdMassAA['M']=131.0404854;
      pdMassAA['H']=137.0589116;
      pdMassAA['F']=147.0684136;
      pdMassAA['R']=156.1011106;
      pdMassAA['Y']=163.0633282;
      pdMassAA['W']=186.0793126;
      pdMassAA['X']=99999.99;
   }
} /*ASSIGN_MASS*/


int main(int argc, char **argv)
{
   // printf("\n");
   printf("# TRYPTIC DIGEST PROGRAM, J.Eng\n");
   // printf("\n");

   if (argc<2)
   {
      printf("   Please enter sequence database on the commandline:\n\n");
      printf("       For example:  %s human.nci\n\n", argv[0]);

      printf("   Results are spit out to stdout in a tab-delimited format.\n");
      printf("   Redirect the output if you want them stored in a file.\n\n");
      printf("       For example:  %s human.nci > digest.txt\n\n", argv[0]);
      exit(1);
   }

   strcpy(pInput.szDb, argv[1]);

   SET_AMINOACID_MASSES(dMassAA, 0);

   /* # of allowed missed cleavages */
   pInput.iMissedCleavage = ALLOWED_MISSED_CLEAVAGES;

   /* defines trypsin cleavage */
   strcpy(pInput.szBreakPoint, "RK");
   strcpy(pInput.szNoBreakPoint, "P");

   /* minimum & maximum peptide masses to print out */
   READ_FASTA();

   return(0);

} /*main*/


void READ_FASTA(void)
{
   int  iLenAllocSeq;
   char szBuf[SIZE_BUF];
   FILE *fp;
   
   iLenAllocSeq = INITIAL_SEQ_LEN;

   pSeq.szSeq = malloc(iLenAllocSeq);
   if (pSeq.szSeq == NULL)
   {
      printf(" Error malloc pSeq.szSeq (%d)\n\n", iLenAllocSeq);
      exit(0);
   }

   if ( (fp=fopen(pInput.szDb, "r"))==NULL)
   {
      printf(" Error - cannot database file %s\n\n", pInput.szDb);
      exit(EXIT_FAILURE);
   }

   while (fgets(szBuf, SIZE_BUF, fp))
   {
      if (szBuf[0]=='>')
      {
         int cResidue;

         strncpy(pSeq.szDef, szBuf+1, MAX_LEN_DEFINITION);
         pSeq.iLenSeq=0;

         while (cResidue=fgetc(fp))
         {
            if (isalpha(cResidue))
            {
               pSeq.szSeq[pSeq.iLenSeq]=cResidue;
               pSeq.iLenSeq++;
               if (pSeq.iLenSeq == iLenAllocSeq-1)
               {
                  char *pTmp;

                  iLenAllocSeq += 500;
                  pTmp = realloc(pSeq.szSeq, iLenAllocSeq);
                  if (pTmp == NULL)
                  {
                     printf(" Error realloc pSeq.szSeq (%d)\n\n", iLenAllocSeq);
                     exit(1);
                  }

                  pSeq.szSeq = pTmp;
               }
            }
            else if (feof(fp) || cResidue=='>')
            {
               int iReturn;

               iReturn=ungetc(cResidue, fp);

               if (iReturn!=cResidue)
               {
                  printf("Error with ungetc.\n\n");
                  exit(EXIT_FAILURE);
               }
               break;
            }
         }

         pSeq.szSeq[pSeq.iLenSeq]='\0';
         FIND_TRYPTIC_PEPTIDES();
      }
   }

   fclose(fp);
    
} /*READ_FASTA*/


void FIND_TRYPTIC_PEPTIDES()
{
   int  iMissed,
        iStartNextPeptide;

   // printf("\n>%s\n", pSeq.szDef);

   pPep.iStart=0;
   pPep.iEnd=0;
   iMissed=0;
   iStartNextPeptide=0;

   do
   {
      if ((strchr(pInput.szBreakPoint, pSeq.szSeq[pPep.iEnd])
              && !strchr(pInput.szNoBreakPoint, pSeq.szSeq[pPep.iEnd+1]))
         || pPep.iEnd==pSeq.iLenSeq-1)
      {
         int i;
 
         pPep.dPepMass = dMassAA['o']+ 3*dMassAA['h'];
         for (i=pPep.iStart; i<=pPep.iEnd; i++)
         {
            pPep.dPepMass += dMassAA[pSeq.szSeq[i]]; 
         }

         /*
          * These peptides pass mass filter
          */
         if (    pPep.dPepMass>=MIN_PEPTIDE_MASS
              && pPep.dPepMass<=MAX_PEPTIDE_MASS
              && pPep.iEnd-pPep.iStart+2<MAX_LEN_PEPTIDE)
         {
            int iTmp;
            char szPeptide[MAX_LEN_PEPTIDE],
                 szDefWord[MAX_LEN_DEFINITION];
            double dMass = dMassAA['o']+dMassAA['h']+dMassAA['h'];

            iTmp=0;
            for (i=pPep.iStart; i<=pPep.iEnd; i++)
            {
               dMass += dMassAA[pSeq.szSeq[i]];
               szPeptide[iTmp]=pSeq.szSeq[i];
               iTmp++;
            }
            szPeptide[iTmp]='\0';

            sscanf(pSeq.szDef, "%s", szDefWord);
            
            /* print header & MH+ mass */
            printf("%s\t%11.2f\t", szDefWord, dMass);

            /* print previous amino acid */
            if (pPep.iStart-1 >= 0)
               printf("%c\t", pSeq.szSeq[pPep.iStart-1]);
            else
               printf("-\t");

            /* print peptide */
            printf("%s", szPeptide);

            /* print following amino acid */
            if (pPep.iEnd+1 < pSeq.iLenSeq)
               printf("\t%c", pSeq.szSeq[pPep.iEnd+1]);
            else
               printf("\t-");

            printf("\t%d\n", pPep.iStart);

         }

         iMissed++;
         if (iMissed==1)  /* first break point is start of next peptide */
            iStartNextPeptide=pPep.iEnd+1;

         if (iMissed <= pInput.iMissedCleavage
               && pPep.dPepMass<MAX_PEPTIDE_MASS
               && pPep.iEnd < pSeq.iLenSeq-1)
         {
            pPep.iEnd++;
         }
         else
         {
            iMissed=0;
            pPep.iStart=iStartNextPeptide;
            pPep.iEnd=pPep.iStart;
         }

      }
      else
      {
         pPep.iEnd++;
      }

   } while (pPep.iStart<pSeq.iLenSeq);

} /*FIND_TRYPTIC_PEPTIDES*/
