/*************************************************************

       Date:  06/23/2000
  
    Purpose:  This program works in conjunction with the addxpress
              program to graphically display the light & heavy ICAT
              peptide elution profiles.  User is able to adjust the
              start & end scans for the above profile displays which
              updates the quantitation ratio calculations based on
              the new peak start/end determination.


  Copyright:  Jimmy Eng, Copyright (c) Institute for Systems Biology, 2000.  All rights reserved.
  
    License:  Use/distribution of this Program is goverened by the following terms:
              1. You may copy and distribute copies of the Program (as source code
                 or executables), in any medium, provided that you conspicuously and
                 appropriately publish on each copy an appropriate copyright notice and
                 disclaimer of warranty; keep intact all the notices that refer to this
                 License and to the absence of any warranty; and give any other recipients
                 of the Program a copy of this License along with the Program. 
              2. You may modify your copy or copies of the Program or any portion of it,
                 thus forming a work based on the Program, and copy and distribute such
                 modifications or work under the terms of Section 1 above, provided that
                 any work that you distribute or publish, that in whole or in part
                 contains or is derived from the Program or any part thereof, must
                 print or display an announcement including the appropriate copyright
                 notice (shown above) and the terms of this License.
              3. By modifying or distributing the Program or any work derived from the
                 Program, you indicate your acceptance of this License.


  Modifications:
  06/30/2000  Need to add in plotting
  10/19/2000  Modify variable names, clean up analysis
  02/02/2001  Plot out smoothed spectrum
  03/06/2001  Add in button to update quantitation in all interact-data files. 
  03/15/2001  Add in bXpressLight1 option (set light or heavy quan to 1)
  04/01/2001  Remove Peptide= link ... only use filename/scan# to ID summary
              lines to update
  06/22/2001  Add in link to update=bad data
  09/13/2001  Add in random number generator for image filename
  04/15/2002  Update to receive interact base filename and pass to updatecgixpress
  07/01/2002  Buttons to swap heavy/light masses for RIC
*************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <tds.h>

#ifdef WIN32
#include "d:\sequest\icatratio\machine.h"
#include "d:\sequest\icatratio\oap_private.h"
#else
#include "icis/machine.h"
#include "icis/oap_private.h"
#endif

/*
 * Include gd library to create gif files
 * see http://www.boutell.com/gd/
 */
#include "gd.h"
#include "gdfonts.h"


#define szVERSION            "XPRESS v.2"
#define szAUTHOR             "by J.Eng &copy; Institute for Systems Biology, 2000. All rights reserved."

#define SIZE_FILE             256
#define MAX_MS_SCANS          20000 

#ifndef TRUE
#define TRUE                  1
#endif
#ifndef FALSE
#define FALSE                 0
#endif

#define SCALE_V(x,y,z,w)      (int)((x-y)*z/w);


int  bXpressLight1;
char szDatFile[SIZE_FILE],
     szOutputFile[SIZE_FILE],
     szInteractBaseName[SIZE_FILE],
     szInteractDir[SIZE_FILE];

struct QuanStruct
{
   int  iquantitation_id;
   int  iChargeState;
   int  iSwapMass;
   int  iLightFirstScan;
   int  iLightLastScan;
   int  iHeavyFirstScan;
   int  iHeavyLastScan;
   double dLightPeptideMass;
   double dHeavyPeptideMass;
   double dLightQuanValue;
   double dHeavyQuanValue;
   double dMassTol;
   char bLightPeptide;
   char szNewQuan[20];
} pQuan;

void PRINT_FORM(char *szArgv0,
        struct QuanStruct *pQuan,
        char *szDatFile,
        char *szOutputFile);
void EXTRACT_QUERY_STRING(struct QuanStruct *pQuan,
        char *szDatFile,
        char *szOutputFile,
        char *szInteractDir,
        char *szInteractBaseName,
        int  *bXpressLight1);
void GET_PARAMETERS(struct QuanStruct *pQuan,
        char *szDatFile,
        char *szOutputFile,
        char *szInteractDir,
        int  *bXpressLight1);
void GET_QUANTITATION(char *szDatFile,
        struct QuanStruct *pQuan);
void MAKE_PLOT(int iPlotStartScan,
        int iPlotEndScan,
        int iLightStartScan,
        int iLightEndScan,
        int iHeavyStartScan,
        int iHeavyEndScan, 
        double dMaxLightInten,
        double dMaxHeavyInten,
        double *pdLight,
        double *pdHeavy,
        double *dLightFiltered,
        double *dHeavyFiltered,
        struct QuanStruct *pQuan);
void FILTER_MS(double *dOrigMS,
        double *dFilteredMS,
        double *dTmpFilter,
        double dMaxInten,
        int    iNumMSScans,
        int    iPlotStartScan,
        int    iPlotEndScan); 
void UPDATE_QUAN(void);
void BAD_QUAN(void);

extern void getword(char *word,
        char *line,
        char stop);
extern void unescape_url(char *url);
extern void plustospace(char *str);


int main(int argc, char **argv)
{

  /*
   * Print html header
   */
   printf("Content-type: text/html\n\n");
   printf("<HTML>\n<HEAD><TITLE>%s, %s</TITLE></HEAD>\n", szVERSION, szAUTHOR);
   printf("<BODY BGCOLOR=\"#FFFFFF\" OnLoad=\"self.focus();\">\n");

   szDatFile[0]='\0'; 
   szOutputFile[0]='\0'; 
   szInteractDir[0]='\0'; 
   szInteractBaseName[0]='\0'; 
   bXpressLight1=0;

   EXTRACT_QUERY_STRING(&pQuan, szDatFile, szOutputFile, szInteractDir,
      szInteractBaseName, &bXpressLight1);

   if (pQuan.iquantitation_id>0 && strlen(szInteractDir)==0)
   {
      GET_PARAMETERS(&pQuan, szDatFile, szOutputFile, szInteractDir, &bXpressLight1);
   }

   if (pQuan.iSwapMass==1)
   {
      pQuan.dHeavyPeptideMass = pQuan.dLightPeptideMass;
      pQuan.dLightPeptideMass -= 8.0;
   }
   else if (pQuan.iSwapMass==2)
   {
      pQuan.dLightPeptideMass = pQuan.dHeavyPeptideMass;
      pQuan.dHeavyPeptideMass += 8.0;
   }

   PRINT_FORM(argv[0], &pQuan, szDatFile, szOutputFile);

   GET_QUANTITATION(szDatFile, &pQuan);


   printf("<TABLE WIDTH=100%%><TR WIDTH=\"100%%\">\n");

   printf("<TD WIDTH=33%% ALIGN=RIGHT>");
   if (strlen(szInteractDir)>1)
   {
      BAD_QUAN();
   }
   printf("</TD><TD WIDTH=33%%>");

   printf("<CENTER>");
   printf("<TABLE><TR><TD ALIGN=RIGHT>Light</TD><TD>:</TD><TD ALIGN=LEFT>Heavy</TD></TR>\n");

   if (pQuan.dLightQuanValue!=0.0)
      printf("<TR><TD ALIGN=RIGHT>1</TD><TD>:</TD><TD ALIGN=LEFT>%0.2f</TD></TR>\n",
         pQuan.dHeavyQuanValue / pQuan.dLightQuanValue);
   else
      printf("<TR><TD ALIGN=RIGHT>1</TD><TD>:</TD><TD ALIGN=LEFT>NaN</TD></TR>\n");

   if (pQuan.dHeavyQuanValue!=0.0)
      printf("<TR><TD ALIGN=RIGHT>%0.2f</TD><TD>:</TD><TD ALIGN=LEFT>1</TD></TR>\n",
         pQuan.dLightQuanValue /  pQuan.dHeavyQuanValue);
   else
      printf("<TR><TD ALIGN=RIGHT>NaN</TD><TD>:</TD><TD ALIGN=LEFT>1</TD></TR>\n");

   printf("</TABLE></CENTER>\n");


   if (bXpressLight1==1)
   {
      if (pQuan.dLightQuanValue == 0.0)
         sprintf(pQuan.szNewQuan, "1:INF");
      else
         sprintf(pQuan.szNewQuan, "1:%0.2f", pQuan.dHeavyQuanValue / pQuan.dLightQuanValue);
   }
   else if (bXpressLight1==2)
   {
      if (pQuan.dHeavyQuanValue == 0.0)
         sprintf(pQuan.szNewQuan, "INF:1");
      else
         sprintf(pQuan.szNewQuan, "%0.2f:1", pQuan.dLightQuanValue / pQuan.dHeavyQuanValue);
   }
   else
   {
      if (pQuan.dLightQuanValue==0.0 && pQuan.dHeavyQuanValue==0.0)
         sprintf(pQuan.szNewQuan, "?");
      else if (pQuan.dLightQuanValue > pQuan.dHeavyQuanValue)
         sprintf(pQuan.szNewQuan, "1:%0.2f", pQuan.dHeavyQuanValue / pQuan.dLightQuanValue);
      else
         sprintf(pQuan.szNewQuan, "%0.2f:1", pQuan.dLightQuanValue / pQuan.dHeavyQuanValue);
   }

   printf("</TD><TD WIDTH=33%% >");

   if (strlen(szInteractDir)>1)
   {
      UPDATE_QUAN();
   }

   printf("</TD></TR></TABLE>\n");

   printf("<P><FONT SIZE= -2>See <A HREF=\"http://www.boutell.com/gd/\">");
   printf("http://www.boutell.com/gd/</A> for info. on the gd graphics library used by this program</FONT>\n");
   printf("</BODY></HTML>\n");

   return(0);

} /*main*/


void PRINT_FORM(char *szArgv0,
        struct QuanStruct *pQuan,
        char *szDatFile,
        char *szOutputFile)
{
   printf("<B><TT>%s, %s</TT></B>\n", szVERSION, szAUTHOR);

#ifdef WIN32
   printf("<FORM METHOD=GET ACTION=\"/cgi-bin/cgixpress.exe\">");
#else
/* printf("<FORM METHOD=GET ACTION=\"/cgi-bin/%s\">", szArgv0); */
   printf("<FORM METHOD=GET ACTION=\"%s\">", szArgv0);
#endif

   printf("<INPUT TYPE=\"hidden\" NAME=\"quantitation_id\" VALUE=\"%d\">\n", pQuan->iquantitation_id);
   printf("<INPUT TYPE=\"hidden\" NAME=\"InteractDir\" VALUE=\"%s\">\n", szInteractDir);
   printf("<INPUT TYPE=\"hidden\" NAME=\"InteractBaseName\" VALUE=\"%s\">\n", szInteractBaseName);
   printf("<INPUT TYPE=\"hidden\" NAME=\"bXpressLight1\" VALUE=\"%d\">\n", bXpressLight1);

   printf("<CENTER><TABLE BORDER CELLPADDING=5>\n");

   printf("<TR VALIGN=TOP><TD BGCOLOR=\"#FFFFDD\">\n");
   printf("<TT>Light scans:");
   printf(" <INPUT TYPE=\"textarea\" NAME=\"LightFirstScan\" VALUE=\"%d\" SIZE=8>\n", pQuan->iLightFirstScan);
   printf(" <INPUT TYPE=\"textarea\" NAME=\"LightLastScan\"  VALUE=\"%d\" SIZE=8>\n", pQuan->iLightLastScan);
   printf(" mass:<INPUT TYPE=\"textarea\" NAME=\"LightMass\" VALUE=\"%0.3f\" SIZE=8>\n", pQuan->dLightPeptideMass);
   printf(" tol: <INPUT TYPE=\"textarea\" NAME=\"MassTol\" VALUE=\"%0.2f\" SIZE=5>", pQuan->dMassTol);

   printf("<BR>Heavy scans:");
   printf(" <INPUT TYPE=\"textarea\" NAME=\"HeavyFirstScan\" VALUE=\"%d\" SIZE=8>\n", pQuan->iHeavyFirstScan);
   printf(" <INPUT TYPE=\"textarea\" NAME=\"HeavyLastScan\"  VALUE=\"%d\" SIZE=8>\n", pQuan->iHeavyLastScan);
   printf(" mass:<INPUT TYPE=\"text\" NAME=\"HeavyMass\" VALUE=\"%0.3f\" SIZE=8>\n", pQuan->dHeavyPeptideMass);

   printf("<P>&nbsp;Raw file:  <input NAME=\"DatFile\" type=textarea VALUE=\"%s\" SIZE=\"50\">\n", szDatFile);
   printf("<BR>.out file:  <input NAME=\"OutFile\" type=textarea VALUE=\"%s\" SIZE=\"50\">", szOutputFile);

   printf("</TD>\n");
   printf("<TD BGCOLOR=\"#FFFFDD\">\n<TT><CENTER>Charge<BR>");
   printf("<INPUT TYPE=\"radio\" NAME=\"ChargeState\" VALUE=\"1\" %s>+1<br>\n", ((pQuan->iChargeState)==1?"checked":""));
   printf("<INPUT TYPE=\"radio\" NAME=\"ChargeState\" VALUE=\"2\" %s>+2<br>\n", ((pQuan->iChargeState)==2?"checked":""));
   printf("<INPUT TYPE=\"radio\" NAME=\"ChargeState\" VALUE=\"3\" %s>+3<BR>\n", ((pQuan->iChargeState)==3?"checked":""));
   printf("<p><INPUT TYPE=\"submit\" VALUE=\"Quantitate\"></CENTER>");
   printf("</TD>\n");

   printf("</TR>\n");

   printf("<TR><TD BGCOLOR=\"#FFFFDD\" COLSPAN=2><CENTER>");
   printf("no mass swap <INPUT TYPE=\"radio\" NAME=\"SwapMass\" VALUE=\"0\" checked>");
   printf(" &nbsp; swap light to heavy <INPUT TYPE=\"radio\" NAME=\"SwapMass\" VALUE=\"1\">");
   printf(" &nbsp; swap heavy to light <INPUT TYPE=\"radio\" NAME=\"SwapMass\" VALUE=\"2\"></CENTER>");
   printf("</TR>\n");

   printf("</TABLE></CENTER>\n");
   printf("</FORM>\n");

} /*PRINT_FORM*/


void EXTRACT_QUERY_STRING(struct QuanStruct *pQuan,
     char *szDatFile,
     char *szOutputFile,
     char *szInteractDir,
     char *szInteractBaseName,
     int  *bXpressLight1)
{
   char *pStr = getenv("REQUEST_METHOD");


   if (pStr==NULL) 
   {
      printf(" Error - this is a CGI program that cannot be\n");
      printf(" run from the command line.\n\n");
      exit(EXIT_FAILURE);
   }
   else if (!strcmp(pStr, "GET"))
   {
      int  i;
      char *szQuery,
           szWord[512];

     /*
      * Get:
      *       ChargeState - charge state of precursor
      */
      szQuery = getenv("QUERY_STRING");
      if (szQuery == NULL)
      {
         printf("<P>No query information to decode.\n");
         printf("</BODY>\n</HTML>\n");
         exit(EXIT_FAILURE);
      }

      for (i=0; szQuery[0] != '\0'; i++)
      {
         getword(szWord, szQuery, '=');
         plustospace(szWord);
         unescape_url(szWord);

         if (!strcmp(szWord, "LightFirstScan"))
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
            sscanf(szWord, "%d", &(pQuan->iLightFirstScan));
         }
         else if (!strcmp(szWord, "LightLastScan") )
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
            sscanf(szWord, "%d", &(pQuan->iLightLastScan));
         }
         else if (!strcmp(szWord, "HeavyFirstScan") )
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
            sscanf(szWord, "%d", &(pQuan->iHeavyFirstScan));
         }
         else if (!strcmp(szWord, "HeavyLastScan") )
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
            sscanf(szWord, "%d", &(pQuan->iHeavyLastScan));
         }
         else if (!strcmp(szWord, "DatFile") )
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
            sscanf(szWord, "%s", szDatFile);
         }
         else if (!strcmp(szWord, "OutFile") )
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
            sscanf(szWord, "%s", szOutputFile);
         }
         else if (!strcmp(szWord, "InteractDir") )
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
            sscanf(szWord, "%s", szInteractDir);
         }
         else if (!strcmp(szWord, "InteractBaseName") )
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
            sscanf(szWord, "%s", szInteractBaseName);
         }
         else if (!strcmp(szWord, "ChargeState") )
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
            sscanf(szWord, "%d", &(pQuan->iChargeState));
         }
         else if (!strcmp(szWord, "SwapMass") )
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
            sscanf(szWord, "%d", &(pQuan->iSwapMass));
         }
         else if (!strcmp(szWord, "LightMass") )
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
            sscanf(szWord, "%lf", &(pQuan->dLightPeptideMass));
         }
         else if (!strcmp(szWord, "HeavyMass") )
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
            sscanf(szWord, "%lf", &(pQuan->dHeavyPeptideMass));
         }
         else if (!strcmp(szWord, "MassTol") )
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
            sscanf(szWord, "%lf", &(pQuan->dMassTol));
         }
         else if (!strcmp(szWord, "bXpressLight1") )
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
            sscanf(szWord, "%d", bXpressLight1);
         }
         else if (!strcmp(szWord, "quantitation_id") )
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
            sscanf(szWord, "%d", &(pQuan->iquantitation_id));
         }
         else
         {
            getword(szWord, szQuery, '&'); plustospace(szWord); unescape_url(szWord);
         }
      } /*for*/
   }
   else
   {
      printf(" Error not called with GET method\n");
      exit(EXIT_FAILURE);
   }
} /*EXTRACT_QUERY_STRING*/



/*#############################################################################
# try_tds_login - Make the connection to the database
#############################################################################*/
int try_tds_login(
   TDSLOGIN  **login,
   TDSSOCKET **tds,
   char *appname,
   int verbose)
{

#ifdef MACROGENICS
   static char SERVER[] = "mssql";
   static char USER[] = "macrog_ro";
   static char PASSWORD[] = "RockMD";
#else
   static char SERVER[] = "mssql";
   static char USER[] = "sbeams";
   static char PASSWORD[] = "SB444";
#endif

   if (verbose)	{ fprintf(stdout, "Entered tds_try_login()<BR>\n"); }
   if (! login) {
      fprintf(stderr, "Invalid TDSLOGIN**\n");
      return TDS_FAIL;
   }
   if (! tds) {
      fprintf(stderr, "Invalid TDSSOCKET**\n");
      return TDS_FAIL;
   }

   if (verbose)	{ fprintf(stdout, "Setting login parameters<BR>\n"); }
   *login = tds_alloc_login();
   if (! *login) {
      fprintf(stderr, "tds_alloc_login() failed.<BR>\n");
      return TDS_FAIL;
   }
   tds_set_passwd(*login, PASSWORD);
   tds_set_user(*login, USER);
   tds_set_app(*login, appname);
   tds_set_host(*login, "myhost");
   tds_set_library(*login, "TDS-Library");
   tds_set_server(*login, SERVER);
   tds_set_charset(*login, "iso_1");
   tds_set_language(*login, "us_english");
   tds_set_packet(*login, 512);
  
   if (verbose)	{ fprintf(stdout, "Connecting to database<BR>\n"); }
   //*tds = tds_connect(*login, NULL);
   *tds = tds_connect(*login,NULL,NULL);
   if (! *tds) {
      fprintf(stderr, "tds_connect() failed<BR>\n");
      return TDS_FAIL;
   }
   if (verbose)	{ fprintf(stdout, "Connected.<BR>\n"); }

   return TDS_SUCCEED;
} /*try_tds_login*/


/*#############################################################################
# GET_PARAMETERS from the database given quantitation_id
#############################################################################*/
void GET_PARAMETERS(struct QuanStruct *pQuan,
     char *szDatFile,
     char *szOutputFile,
     char *szInteractDir,
     int  *bXpressLight1)
{

   TDSLOGIN *login;
   TDSSOCKET *tds;
   int verbose = 0;
   int num_cols = 2;
   int rc;
   int i,col_idx;
   int iStrLength;
   int DEBUG=FALSE;

   char column_name[255];
   int type;
   char *ptr_row;
   int offset;
   void *ptr_value;

   char sql_query[1024];


#ifdef MACROGENICS
   static char DATABASE[] = "MGproteomics";
#else
   static char DATABASE[] = "proteomics";
#endif


   //#### Build the query string
   if (DEBUG) printf("\n\nquantition_id = %d<BR>\n\n\n\n\n",pQuan->iquantitation_id);
   sprintf(sql_query,"
     USE %s
     SELECT d0_first_scan,d0_last_scan,d0_mass,d8_first_scan,d8_last_scan,d8_mass,
            norm_flag,mass_tolerance,'/local/data/proteomics/'+SB.data_location+'/../'+
            F.fraction_tag AS 'dat_file',S.assumed_charge
       FROM dbo.quantitation Q
       JOIN dbo.search_hit SH ON ( Q.search_hit_id = SH.search_hit_id )
       JOIN dbo.search S ON ( SH.search_id = S.search_id )
       JOIN dbo.search_batch SB ON ( S.search_batch_id = SB.search_batch_id )
       JOIN dbo.msms_spectrum MSS ON ( S.msms_spectrum_id = MSS.msms_spectrum_id )
       JOIN dbo.fraction F ON ( MSS.fraction_id = F.fraction_id )
      WHERE quantitation_id = '%d'",
      DATABASE,pQuan->iquantitation_id);


   //#### Connect and login to database
   rc = try_tds_login(&login, &tds, "Xpress.cgi", verbose);
   if (rc != TDS_SUCCEED) {
      fprintf(stderr, "try_tds_login() failed\n");
      return;
   }


   //#### Issue query
   if (DEBUG) printf("<PRE>\n%s\n\n</PRE>\n",sql_query);
   rc = tds_submit_query(tds,sql_query);
   if (rc != TDS_SUCCEED) {
      fprintf(stderr, "tds_submit_query() failed\n");
      printf("tds_submit_query() failed<BR>\n");
      return;
   }


   //#### Loop over all returned result sets
   while ((rc=tds_process_result_tokens(tds))==TDS_SUCCEED) {

      //#### Determine number of columns in this result set
      num_cols = tds->res_info->num_cols;
      if (DEBUG) printf("Number of columns in resultset: %d<BR>\n",num_cols);

      //#### Loop over all rows in the result set
      while ((rc=tds_process_row_tokens(tds))==TDS_SUCCEED) {

         //#### Loop over all columns in the row, processing certain values
         for (col_idx=0; col_idx<num_cols; col_idx++) {
	    strcpy(column_name,tds->res_info->columns[col_idx]->column_name);
            type = tds->res_info->columns[col_idx]->column_type;
            ptr_row = tds->res_info->current_row;
            offset = tds->res_info->columns[col_idx]->column_offset;
            ptr_value = (ptr_row+offset);

	    if (strcmp(column_name,"d0_first_scan")==0) {
	       pQuan->iLightFirstScan = *(int *)ptr_value;
               if (DEBUG) printf("  %s = %d<BR>\n",column_name,pQuan->iLightFirstScan);
	    }
            else if (strcmp(column_name,"d0_last_scan")==0) {
	       pQuan->iLightLastScan = *(int *)ptr_value;
               if (DEBUG) printf("  %s = %d<BR>\n",column_name,pQuan->iLightLastScan);
	    }
            else if (strcmp(column_name,"d0_mass")==0) {
	       pQuan->dLightPeptideMass = *(float *)ptr_value;
               if (DEBUG) printf("  %s = %f<BR>\n",column_name,pQuan->dLightPeptideMass);
	    }

            else if (strcmp(column_name,"d8_first_scan")==0) {
	       pQuan->iHeavyFirstScan = *(int *)ptr_value;
               if (DEBUG) printf("  %s = %d<BR>\n",column_name,pQuan->iHeavyFirstScan);
	    }
            else if (strcmp(column_name,"d8_last_scan")==0) {
	       pQuan->iHeavyLastScan = *(int *)ptr_value;
               if (DEBUG) printf("  %s = %d<BR>\n",column_name,pQuan->iHeavyLastScan);
	    }
            else if (strcmp(column_name,"d8_mass")==0) {
	       pQuan->dHeavyPeptideMass = *(float *)ptr_value;
               if (DEBUG) printf("  %s = %f<BR>\n",column_name,pQuan->dHeavyPeptideMass);
	    }

            else if (strcmp(column_name,"norm_flag")==0) {
	       bXpressLight1 = (int *)ptr_value;
               if (DEBUG) printf("  %s = %d<BR>\n",column_name,*bXpressLight1);
	    }
            else if (strcmp(column_name,"mass_tolerance")==0) {
	       pQuan->dMassTol = *(float *)ptr_value;
               if (DEBUG) printf("  %s = %f<BR>\n",column_name,pQuan->dMassTol);
	    }

            else if (strcmp(column_name,"assumed_charge")==0) {
	       pQuan->iChargeState = *(int *)ptr_value;
               if (DEBUG) printf("  %s = %d<BR>\n",column_name,pQuan->iChargeState);
	    }

            else if (strcmp(column_name,"dat_file")==0) {
	       iStrLength = strlen((char *)ptr_value);
	       if (iStrLength > SIZE_FILE) iStrLength = SIZE_FILE;
               strncpy(szDatFile, (char *)ptr_value, iStrLength);
               szDatFile[iStrLength] = '\0';
               if (DEBUG) printf("  %s = %s<BR>\n",column_name,szDatFile);
	    }

         }

      }


      //#### Check for unexpected status codes
      if (rc == TDS_FAIL) {
         fprintf(stderr, "tds_process_row_tokens() returned TDS_FAIL\n");
      }
      else if (rc != TDS_NO_MORE_ROWS) {
         fprintf(stderr, "tds_process_row_tokens() unexpected return\n");
      }

   }


   //#### Check for unexpected status codes
   if (rc == TDS_FAIL) {
      fprintf(stderr, "tds_process_result_tokens() returned TDS_FAIL\n");
   }
   else if (rc != TDS_NO_MORE_RESULTS) {
      fprintf(stderr, "tds_process_result_tokens() unexpected return\n");
   }


   //#### Logout of server
   if (DEBUG) printf("No more rows.  Query finished.<BR>\n");
   tds_free_socket(tds);
   tds_free_login(login);


   //#### Set szInteractDir to something bogus but non-blank to simulate
   //#### the Interact environment
   if (!(strlen(szInteractDir)>0)) {
     strcpy(szInteractDir,"SBEAMS");
   }


} /*GET_PARAMETERS*/




/*
 * Reads .dat files and get quantitation numbers
 */
void GET_QUANTITATION(char *szDatFile,
        struct QuanStruct *pQuan)
{
   int    i,
          ctScan,
          iAnalysisFirstScan,
          iAnalysisLastScan,
          iLightStartScan,
          iLightEndScan,
          iHeavyStartScan,
          iHeavyEndScan,
          iPlotStartScan,
          iPlotEndScan,
          iPlotBuffer=25,
          iStart,
          iEnd,
          iWhichCharge;

   double dLightMass,
          dHeavyMass,
          H=1.008,
          *dLightMS,
          *dHeavyMS,
          *dLightFilteredMS,
          *dHeavyFilteredMS,
          *dTmpMS,
          dMaxLightInten,
          dMaxHeavyInten;

   char   szTmpFile[SIZE_FILE];

   int    iSumPeaks=0;

   OAP_FILE *pOapFile;
   SPECTRUM *pSpectrum;
   ANALYSIS *pAnalysis;


   sprintf(szTmpFile, "%s.dat", szDatFile);

  /*
   * Open icis file
   */
   if ((pOapFile = oap_open(szTmpFile, READ_FLAG)) == NULL)
   {
      printf(" Cannot open analysis - %s\n", szTmpFile);
      exit(EXIT_FAILURE);
   }

  /*
   * Get the analysis start, end scans
   */
   if ((pAnalysis = get_header(pOapFile, 0)) != NULL)
   {
      iAnalysisFirstScan = (INT_4) pAnalysis->first_spect;
      iAnalysisLastScan  = (INT_4) pAnalysis->last_spect;
   }
   else
   {
      printf(" Unable to read the analysis header of %s!\n", szDatFile);
      exit(EXIT_FAILURE);
   }

   if ( (dLightMS=(double *)malloc(sizeof(double)*(iAnalysisLastScan+5)))==NULL)
   {
      printf(" Error, cannot malloc dLightMS[%d]\n\n", iAnalysisLastScan+5);
      exit(EXIT_FAILURE);
   }
   if ( (dHeavyMS=(double *)malloc(sizeof(double)*(iAnalysisLastScan+5)))==NULL)
   {
      printf(" Error, cannot malloc dHeavyMS[%d]\n\n", iAnalysisLastScan+5);
      exit(EXIT_FAILURE);
   }
   if ( (dLightFilteredMS=malloc(sizeof(double)*(iAnalysisLastScan+5)))==NULL)
   {
      printf(" Error, cannot malloc dLightFilteredMS[%d]\n\n", iAnalysisLastScan+5);
      exit(EXIT_FAILURE);
   }
   if ( (dHeavyFilteredMS=malloc(sizeof(double)*(iAnalysisLastScan+5)))==NULL)
   {
      printf(" Error, cannot malloc dHeavyFilteredMS[%d]\n\n", iAnalysisLastScan+5);
      exit(EXIT_FAILURE);
   }
   if ( (dTmpMS=malloc(sizeof(double)*(iAnalysisLastScan+5)))==NULL)
   {
      printf(" Error, cannot malloc dTmpMS[%d]\n\n", iAnalysisLastScan+5);
      exit(EXIT_FAILURE);
   }  

   iWhichCharge=pQuan->iChargeState;

  /*
   * Calculate the precursor mass
   */
   if (iWhichCharge==1)
   {
      dLightMass = pQuan->dLightPeptideMass;
      dHeavyMass = pQuan->dHeavyPeptideMass;
   }
   else if (iWhichCharge==2)
   {
      dLightMass = (H+ pQuan->dLightPeptideMass)/2.0;
      dHeavyMass = (H+ pQuan->dHeavyPeptideMass)/2.0;
   }
   else if (iWhichCharge==3)
   {
      dLightMass = (H+H + pQuan->dLightPeptideMass)/3.0;
      dHeavyMass = (H+H + pQuan->dHeavyPeptideMass)/3.0;
   }
   else
   {
      printf(" Error, charge state = %d\n\n", iWhichCharge);
      exit(EXIT_FAILURE);
   }

  /*
   * Clear all values
   */
   memset(dLightMS, 0, sizeof(dLightMS));
   memset(dHeavyMS, 0, sizeof(dHeavyMS));
   memset(dLightFilteredMS, 0, sizeof(dLightFilteredMS));
   memset(dHeavyFilteredMS, 0, sizeof(dHeavyFilteredMS)); 

   iStart = pQuan->iLightFirstScan - 100;
   iEnd = pQuan->iLightLastScan + 100;

   if (iStart<iAnalysisFirstScan)
      iStart=iAnalysisFirstScan;
   if (iEnd>iAnalysisLastScan)
      iEnd=iAnalysisLastScan;

  /*
   * Read all MS scan values
   */

   for (ctScan=iStart; ctScan<=iEnd; ctScan++)
   {
     /*
      * Open a scan
      */
      if ((pSpectrum=get_spectrum(pOapFile, ctScan, TRUE)) != NULL)
      {
         if ( (pSpectrum->spect_flags[0]&16) && (pSpectrum->spect_flags[5]&16) )
         {
            DATA_PKT *pDataPt;

           /*
            * Store intensity value for each peptide/charge
            * mass across all MS scans in the datafile.
            */
            while ((pDataPt=get_packet(pOapFile, 0))!=NULL)
            {                  

	       if ( fabs(dLightMass - pDataPt->mass) <= pQuan->dMassTol) {
		  if (iSumPeaks == 1) {
                     dLightMS[ctScan]+=pDataPt->intensity;
                  } else {
	             if (pDataPt->intensity > dLightMS[ctScan])
                        dLightMS[ctScan]=pDataPt->intensity;
                  }
               }

               if ( fabs(dHeavyMass - pDataPt->mass) <= pQuan->dMassTol) {
		  if (iSumPeaks == 1) {
                     dHeavyMS[ctScan]+=pDataPt->intensity;
                  } else {
		     if (pDataPt->intensity > dHeavyMS[ctScan])
                        dHeavyMS[ctScan]=pDataPt->intensity;
                  }
               }

            }
         }
      }
   } /*for*/

  /*
   * Starting from the start and end scans read from .out
   * files, need to see the real start/end scan of eluting
   * peptide by looking at smoothed/filtered MS profile.
   */

  /*
   * Get peptide start & end scans
   */
   iLightStartScan = pQuan->iLightFirstScan;
   iLightEndScan = pQuan->iLightLastScan;
   iHeavyStartScan = pQuan->iHeavyFirstScan;
   iHeavyEndScan = pQuan->iHeavyLastScan;

  /*
   * Print out data for plotting
   */
   iPlotStartScan = iLightStartScan;
   iPlotEndScan = iLightEndScan;

   if (iHeavyStartScan < iPlotStartScan)
      iPlotStartScan = iHeavyStartScan;
   if (iHeavyEndScan > iPlotEndScan)
      iPlotEndScan = iHeavyEndScan;

   if (iPlotStartScan-iPlotBuffer < iAnalysisFirstScan)
      iPlotStartScan = iAnalysisFirstScan;
   else
      iPlotStartScan -= iPlotBuffer;

   if (iPlotEndScan+iPlotBuffer> iAnalysisLastScan-1)
      iPlotEndScan = iAnalysisLastScan-1;
   else
      iPlotEndScan += iPlotBuffer;

   dMaxLightInten=0.0;
   dMaxHeavyInten=0.0;

   for (i=iPlotStartScan; i<=iPlotEndScan; i++)
   {
      if (dLightMS[i]>dMaxLightInten)
         dMaxLightInten=dLightMS[i];
      if (dHeavyMS[i]>dMaxHeavyInten)
         dMaxHeavyInten=dHeavyMS[i];
   }

  /*
   * Sum up intensity values across each charge state
   */
   for (i=iLightStartScan; i<=iLightEndScan; i++)
      pQuan->dLightQuanValue += dLightMS[i];
   for (i=iHeavyStartScan; i<=iHeavyEndScan; i++)
      pQuan->dHeavyQuanValue += dHeavyMS[i];

   memset(dTmpMS, 0, sizeof(dTmpMS));
   FILTER_MS(dLightMS, dLightFilteredMS, dTmpMS, dMaxLightInten,
      iAnalysisLastScan+5, iPlotStartScan, iPlotEndScan);

   memset(dTmpMS, 0, sizeof(dTmpMS));
   FILTER_MS(dHeavyMS, dHeavyFilteredMS, dTmpMS, dMaxHeavyInten,
      iAnalysisLastScan+5, iPlotStartScan, iPlotEndScan); 

if (dLightMS[iLightStartScan]!=0.0)
   iLightStartScan--;
if (dLightMS[iLightEndScan]!=0.0)
   iLightEndScan++;

if (dHeavyMS[iHeavyStartScan]!=0.0)
   iHeavyStartScan--;
if (dHeavyMS[iHeavyEndScan]!=0.0)
   iHeavyEndScan++;

   MAKE_PLOT(iPlotStartScan, iPlotEndScan, iLightStartScan, iLightEndScan,
      iHeavyStartScan, iHeavyEndScan, dMaxLightInten, dMaxHeavyInten,
      dLightMS, dHeavyMS, dLightFilteredMS, dHeavyFilteredMS, pQuan);

   free(dLightMS);
   free(dHeavyMS);
   oap_close(pOapFile); 

} /*GET_QUANTITATION*/


void MAKE_PLOT(int iPlotStartScan,
        int iPlotEndScan,
        int iLightStartScan,
        int iLightEndScan,
        int iHeavyStartScan,
        int iHeavyEndScan, 
        double dMaxLightInten,
        double dMaxHeavyInten,
        double *pdLight,
        double *pdHeavy,
        double *pdLightFiltered,
        double *pdHeavyFiltered,
        struct QuanStruct *pQuan)
{
   int  i,
        iImageWidth=450,
        iImageHeight=150,
        iBottomBorder=20,
        iTopBorder=10,
        iGrey,
        iGrey2,
        iWhite,
        iWhite2,
        iBlack,
        iBlack2,
        iRed,
        iRed2,
        iBlue,
        iBlue2;
   char szImageFile[SIZE_FILE],
        szImageFile2[SIZE_FILE],
        szImageDir[SIZE_FILE],
        szLabel[SIZE_FILE];
   FILE *fp;
   double H=1.008;
   time_t tStartTime;

   gdImagePtr gdImageLight,
              gdImageHeavy;


  /*
   * first color allocated defines background color
   */
   gdImageLight = gdImageCreate(iImageWidth, iImageHeight);   
   iWhite =  gdImageColorAllocate(gdImageLight, 248, 255, 255),
   iGrey  =  gdImageColorAllocate(gdImageLight, 150, 150, 150),
   iBlack =  gdImageColorAllocate(gdImageLight, 0, 0, 0),
   iRed   =  gdImageColorAllocate(gdImageLight, 255, 0, 0),
   iBlue  =  gdImageColorAllocate(gdImageLight, 0, 0, 255),


   gdImageHeavy = gdImageCreate(iImageWidth, iImageHeight);   
   iWhite2 = gdImageColorAllocate(gdImageHeavy, 255, 248, 255),
   iGrey2  = gdImageColorAllocate(gdImageHeavy, 150, 150, 150),
   iBlack2 = gdImageColorAllocate(gdImageHeavy, 0, 0, 0),
   iRed2   = gdImageColorAllocate(gdImageHeavy, 255, 0, 0),
   iBlue2  = gdImageColorAllocate(gdImageHeavy, 0, 0, 255),

   sprintf(szLabel, "Light %0.3lf %+d",
      (pQuan->dLightPeptideMass + H*(pQuan->iChargeState -1)) /(pQuan->iChargeState),
      pQuan->iChargeState);
   gdImageString(gdImageLight, gdFontSmall, 3, 3, szLabel, iBlue);
   sprintf(szLabel, "AREA:%0.2E", pQuan->dLightQuanValue);
   gdImageString(gdImageLight, gdFontSmall, 3, 15, szLabel, iBlue);
   sprintf(szLabel, "%0.2E", dMaxLightInten);
   gdImageString(gdImageLight, gdFontSmall, iImageWidth-50, 3, szLabel, iBlue);
 
   sprintf(szLabel, "Heavy %0.3lf %+d",
      (pQuan->dHeavyPeptideMass + H*(pQuan->iChargeState -1)) /(pQuan->iChargeState),
      pQuan->iChargeState);
   gdImageString(gdImageHeavy, gdFontSmall, 3, 3, szLabel, iBlue2);
   sprintf(szLabel,"AREA:%0.2E", pQuan->dHeavyQuanValue);
   gdImageString(gdImageHeavy, gdFontSmall, 3, 15, szLabel, iBlue2);
   sprintf(szLabel,"%0.2E", dMaxHeavyInten);
   gdImageString(gdImageHeavy, gdFontSmall, iImageWidth-50, 3, szLabel, iBlue2); 

  /*
   * Plot out spectra
   */
   for (i=iPlotStartScan; i<=iPlotEndScan; i++)
   {
      int iX1Pos,
          iX2Pos,
          iY1PosLight,
          iY2PosLight,
          iY1PosHeavy,
          iY2PosHeavy;
      gdPoint gPoints[4];


      iX1Pos= (int)( (i-iPlotStartScan)*iImageWidth/(iPlotEndScan-iPlotStartScan));
      iX2Pos= (int)( (i+1-iPlotStartScan)*iImageWidth/(iPlotEndScan-iPlotStartScan));

      if (dMaxLightInten>0.0)
      {
         iY1PosLight = iImageHeight - iBottomBorder -
            (int)((pdLight[i]/dMaxLightInten)*(iImageHeight-iBottomBorder-iTopBorder));
         iY2PosLight = iImageHeight - iBottomBorder -
            (int)((pdLight[i+1]/dMaxLightInten)*(iImageHeight-iBottomBorder-iTopBorder));
      }
      else
      {
         iY1PosLight = iImageHeight - iBottomBorder;
         iY2PosLight = iImageHeight - iBottomBorder;
      }

      if (dMaxHeavyInten>0.0)
      {
         iY1PosHeavy = iImageHeight - iBottomBorder -
            (int)((pdHeavy[i]/dMaxHeavyInten)*(iImageHeight-iBottomBorder-iTopBorder));
         iY2PosHeavy = iImageHeight - iBottomBorder -
            (int)((pdHeavy[i+1]/dMaxHeavyInten)*(iImageHeight-iBottomBorder-iTopBorder));
      }
      else
      {
         iY1PosHeavy = iImageHeight - iBottomBorder;
         iY2PosHeavy = iImageHeight - iBottomBorder;
      }

     /*
      * define triangle for filled polygon ... one of many ways to display trace
      */
      gPoints[0].x = iX1Pos;
      gPoints[0].y = iImageHeight-iBottomBorder;
      gPoints[1].x = iX1Pos;
      gPoints[1].y = iY1PosLight;
      gPoints[2].x = iX2Pos;
      gPoints[2].y = iY2PosLight;
      gPoints[3].x = iX2Pos;
      gPoints[3].y = iImageHeight-iBottomBorder;

      if (i>=iLightStartScan && i<iLightEndScan)
      {
         gdImageFilledPolygon(gdImageLight, gPoints, 4, iRed);
/*
         gdImageLine(gdImageLight, iX1Pos, iY1PosLight, iX2Pos, iY2PosLight, iBlack);
*/
      }
      else
      {
         gdImageFilledPolygon(gdImageLight, gPoints, 4, iGrey);
/*
         gdImageLine(gdImageLight, iX1Pos, iY1PosLight, iX2Pos, iY2PosLight, iBlack);
*/
      }

      gPoints[1].y=iY1PosHeavy;
      gPoints[2].y=iY2PosHeavy;
      if (i>=iHeavyStartScan && i<iHeavyEndScan)
      {
         gdImageFilledPolygon(gdImageHeavy, gPoints, 4, iRed2);
/*
         gdImageLine(gdImageHeavy, iX1Pos, iY1PosHeavy, iX2Pos, iY2PosHeavy, iBlack2);
*/
      }
      else
      {
         gdImageFilledPolygon(gdImageHeavy, gPoints, 4, iGrey2);
/*
         gdImageLine(gdImageHeavy, iX1Pos, iY1PosHeavy, iX2Pos, iY2PosHeavy, iBlack2);
*/
      }

     /*
      * Plot out smoothed trace
      */
      if (dMaxLightInten>0.0)
      {
         iY1PosLight = iImageHeight - iBottomBorder -
            (int)((pdLightFiltered[i]/dMaxLightInten)*(iImageHeight-iBottomBorder-iTopBorder));
      }
      else
      {
         iY1PosLight= iImageHeight - iBottomBorder;
      }
      if (dMaxHeavyInten>0.0)
      {
         iY1PosHeavy = iImageHeight - iBottomBorder -
            (int)((pdHeavyFiltered[i]/dMaxHeavyInten)*(iImageHeight-iBottomBorder-iTopBorder));
      }
      else
      {
         iY1PosHeavy = iImageHeight - iBottomBorder;
      }

      if (i>=iLightStartScan && i<iLightEndScan)
         gdImageSetPixel(gdImageLight, iX1Pos, iY1PosLight, iBlue);
      else
         gdImageSetPixel(gdImageLight, iX1Pos, iY1PosLight, iRed);

      if (i>=iHeavyStartScan && i<iHeavyEndScan)
         gdImageSetPixel(gdImageHeavy, iX1Pos, iY1PosHeavy,  iBlue2);
      else
         gdImageSetPixel(gdImageHeavy, iX1Pos, iY1PosHeavy,  iRed2); 


      sprintf(szLabel, "%d", i);

     /*
      * x-label, tick marks
      */
      if (iPlotEndScan-iPlotStartScan<150)
      {
         if ( !(i%10))
         {
            gdImageString(gdImageLight, gdFontSmall, iX1Pos-10, iImageHeight-13, szLabel, iBlue);
            gdImageString(gdImageHeavy, gdFontSmall, iX1Pos-10, iImageHeight-13, szLabel, iBlue2);
         }
         if ( !(i%5))
         {
           /*
            * big tick marks
            */
            gdImageLine(gdImageLight, iX1Pos, iImageHeight-iBottomBorder,
               iX1Pos, iImageHeight-iBottomBorder+5, iBlack);
            gdImageLine(gdImageHeavy, iX1Pos, iImageHeight-iBottomBorder,
               iX1Pos, iImageHeight-iBottomBorder+5, iBlack2);
         }

           /*
            * tick marks
            */
            gdImageLine(gdImageLight, iX1Pos, iImageHeight-iBottomBorder,
               iX1Pos, iImageHeight-iBottomBorder+2, iBlack);
            gdImageLine(gdImageHeavy, iX1Pos, iImageHeight-iBottomBorder,
               iX1Pos, iImageHeight-iBottomBorder+2, iBlack2);
      }
      else if  (iPlotEndScan-iPlotStartScan<500)
      {
         if ( !(i%50))
         {
            gdImageString(gdImageLight, gdFontSmall, iX1Pos-10, iImageHeight-13, szLabel, iBlue);
            gdImageString(gdImageHeavy, gdFontSmall, iX1Pos-10, iImageHeight-13, szLabel, iBlue2);
         }
         if ( !(i%10))
         {
           /*
            * big tick marks
            */
            gdImageLine(gdImageLight, iX1Pos, iImageHeight-iBottomBorder,
               iX1Pos, iImageHeight-iBottomBorder+5, iBlack);
            gdImageLine(gdImageHeavy, iX1Pos, iImageHeight-iBottomBorder,
               iX1Pos, iImageHeight-iBottomBorder+5, iBlack2);
         }
         if ( !(i%5))
         {
           /*
            * tick marks
            */
            gdImageLine(gdImageLight, iX1Pos, iImageHeight-iBottomBorder,
               iX1Pos, iImageHeight-iBottomBorder+2, iBlack);
            gdImageLine(gdImageHeavy, iX1Pos, iImageHeight-iBottomBorder,
               iX1Pos, iImageHeight-iBottomBorder+2, iBlack2);
         }
      } 
      else
      {
         if ( !(i%100))
         {
            gdImageString(gdImageLight, gdFontSmall, iX1Pos-10, iImageHeight-13, szLabel, iBlue);
            gdImageString(gdImageHeavy, gdFontSmall, iX1Pos-10, iImageHeight-13, szLabel, iBlue2);
         }
         if ( !(i%50))
         {
           /*
            * big tick marks
            */
            gdImageLine(gdImageLight, iX1Pos, iImageHeight-iBottomBorder,
               iX1Pos, iImageHeight-iBottomBorder+5, iBlack);
            gdImageLine(gdImageHeavy, iX1Pos, iImageHeight-iBottomBorder,
               iX1Pos, iImageHeight-iBottomBorder+5, iBlack2);
         }
         if ( !(i%10))
         {
           /*
            * tick marks
            */
            gdImageLine(gdImageLight, iX1Pos, iImageHeight-iBottomBorder,
               iX1Pos, iImageHeight-iBottomBorder+2, iBlack);
            gdImageLine(gdImageHeavy, iX1Pos, iImageHeight-iBottomBorder,
               iX1Pos, iImageHeight-iBottomBorder+2, iBlack2);
         }
      } 
   }


  /*
   * Draw axis
   */
   gdImageLine(gdImageLight, 0, iImageHeight-iBottomBorder,
      iImageWidth-1, iImageHeight-iBottomBorder, iBlack);
   gdImageLine(gdImageHeavy, 0, iImageHeight-iBottomBorder,
      iImageWidth-1, iImageHeight-iBottomBorder, iBlack2);

  /*
   * Draw box around image
   */
   gdImageRectangle(gdImageLight, 0, 0, iImageWidth-1, iImageHeight-1, iBlack);
   gdImageRectangle(gdImageHeavy, 0, 0, iImageWidth-1, iImageHeight-1, iBlack2);


  /*
   * Create the image file ... image_buffer needs to point to data
   */

/*
 * These definitely need to be read from somewhere ... szImageDir
 */
#ifdef WIN32
   sprintf(szImageDir, "c:\\website\\htdocs\\");
#else
   sprintf(szImageDir, "../../images/tmp/");
#endif

#ifdef WIN32
   strcpy(szImageFile, "erase ");
#else
   strcpy(szImageFile, "rm -f ");
#endif

   strcat(szImageFile+strlen(szImageFile), szImageDir);
   strcat(szImageFile+strlen(szImageFile), "x*.gif");
   system(szImageFile);

  /*
   * Create the image file ... make unique name for each image file
   */
   srandom(pQuan->iLightFirstScan+pQuan->iHeavyFirstScan+ (int)(pQuan->dLightPeptideMass*5.0));
   tStartTime=time((time_t *)NULL);
   strcpy(szImageFile, szImageDir);
   strcpy(szImageFile2, szImageDir);
   sprintf(szImageFile+strlen(szImageFile), "x%d-%d.gif", tStartTime, random());
   sprintf(szImageFile2+strlen(szImageFile2), "x%d-%db.gif", tStartTime, random());

   gdImageInterlace(gdImageLight, 1);
   if ( (fp=fopen(szImageFile, "wb"))!=NULL)
   {
      gdImageGif(gdImageLight, fp);
      fclose(fp);
      gdImageDestroy(gdImageLight);  
   }
   else
      printf(" Error - cannot create file %s<BR>\n", szImageFile);

   gdImageInterlace(gdImageHeavy, 1);
   if ( (fp=fopen(szImageFile2, "wb"))!=NULL)
   {
      gdImageGif(gdImageHeavy, fp);
      fclose(fp);
      gdImageDestroy(gdImageHeavy);
   }
   else
      printf(" Error - cannot create file %s<BR>\n", szImageFile2);

   printf("<CENTER><img src=\"%s\"><BR><img src=\"%s\"></CENTER>", szImageFile, szImageFile2);

} /*MAKE_PLOT*/



#define FILTER_SIZE 6
/*
 * Use my standard filtering routine
 */
void FILTER_MS(double *dOrigMS,
        double *dFilteredMS,
        double *dTmpFilter,
        double dMaxInten,
        int    iNumMSScans,
        int    iPlotStartScan,
        int    iPlotEndScan)
{
   int  i,
        iArraySize=iNumMSScans*sizeof(double);
   double dTmpMax;
 
  /*
   * Defines 5th order butterworth filter w/ cut-off frequency
   * of 0.25 where 1.0 corresponse to half the sample rate.
   */

/*
   5th order, 0.10
   double a[FILTER_SIZE]={1.0000, -3.9845, 6.4349, -5.2536, 2.1651, -0.3599},
          b[FILTER_SIZE]={0.0000598, 0.0002990, 0.0005980, 0.0005980, 0.0002990, 0.0000598};

   5th order, 0.15
*/
   double a[FILTER_SIZE]={1.0000, -3.4789, 5.0098, -3.6995, 1.3942, -0.2138},
          b[FILTER_SIZE]={0.0004, 0.0018, 0.0037, 0.0037, 0.0018, 0.0004};

/*
   5th order, 0.20
   double a[FILTER_SIZE]={1.0000, -2.9754, 3.8060, -2.5453, 0.8811, -0.1254},
          b[FILTER_SIZE]={0.0013, 0.0064, 0.0128, 0.0128, 0.0064, 0.0013};

   5th order, 0.25
   double a[FILTER_SIZE]={1.0, -2.4744, 2.8110, -1.7038, 0.5444, -0.0723},
          b[FILTER_SIZE]={0.0033, 0.0164, 0.0328, 0.0328, 0.0164, 0.0033};
*/

 
   memset(dFilteredMS, 0, iArraySize);
   memcpy(dTmpFilter, dOrigMS, iNumMSScans*sizeof(double));
 
  /*
   * Pass MS profile through IIR low pass filter:
   * y(n) = b(1)*x(n) + b(2)*x(n-1) + ... + b(nb+1)*x(n-nb)
   *      - a(2)*y(n-1) - ... - a(na+1)*y(n-na)
   */
   for (i=0; i<iNumMSScans; i++)
   {
      int ii;

      dFilteredMS[i]=b[0]*dTmpFilter[i];
      for (ii=1;ii<FILTER_SIZE;ii++)
      {
         if ((i-ii)>=0)
         {
            dFilteredMS[i] += b[ii]*dTmpFilter[i-ii];
            dFilteredMS[i] -= a[ii]*dFilteredMS[i-ii];
         }
      }
   }
 
  /*
   * Filtered sequence is reversed and re-filtered resulting
   * in zero-phase distortion and double the filter order.
   */
   for (i=0; i<iNumMSScans; i++)
      dTmpFilter[i]=dFilteredMS[iNumMSScans-1-i];
 
   memset(dFilteredMS, 0, iArraySize);
   for (i=0; i<iNumMSScans; i++) 
   {
      int ii;
 
      dFilteredMS[i]=b[0]*dTmpFilter[i];
      for (ii=1;ii<FILTER_SIZE;ii++)
      {
         if ((i-ii)>=0)
         {
            dFilteredMS[i] += b[ii]*dTmpFilter[i-ii];
            dFilteredMS[i] -= a[ii]*dFilteredMS[i-ii];
         }
      }
   }
 
  /*
   * Filtered sequence is reversed again
   */
   dTmpMax=0.001;
   for (i=0; i<iNumMSScans; i++)
   {
      dTmpFilter[i]=dFilteredMS[iNumMSScans-1-i];

      if (i>=iPlotStartScan && i<=iPlotEndScan)
         if (dTmpFilter[i]>dTmpMax)
            dTmpMax=dTmpFilter[i];
   }

   if (dMaxInten>0.0)
   {
      for (i=iPlotStartScan; i<=iPlotEndScan; i++)
      {
         dTmpFilter[i] = dTmpFilter[i] * dMaxInten / dTmpMax;
      }
   }

   memcpy(dFilteredMS, dTmpFilter, iArraySize);
 
} /*FILTER_MS*/


void UPDATE_QUAN()
{
   char szNewLink[4096];

  /*
   * replace text starting with first ? in the cgixpress tag with szNewLink
   */
   sprintf(szNewLink                  , "LightFirstScan=%d&amp;", pQuan.iLightFirstScan);
   sprintf(szNewLink+strlen(szNewLink), "LightLastScan=%d&amp;",  pQuan.iLightLastScan);
   sprintf(szNewLink+strlen(szNewLink), "LightMass=%0.6lf&amp;",  pQuan.dLightPeptideMass);
   sprintf(szNewLink+strlen(szNewLink), "HeavyFirstScan=%d&amp;", pQuan.iHeavyFirstScan);
   sprintf(szNewLink+strlen(szNewLink), "HeavyLastScan=%d&amp;",  pQuan.iHeavyLastScan);
   sprintf(szNewLink+strlen(szNewLink), "HeavyMass=%0.6f&amp;",   pQuan.dHeavyPeptideMass);
   sprintf(szNewLink+strlen(szNewLink), "DatFile=%s&amp;",        szDatFile);
   sprintf(szNewLink+strlen(szNewLink), "ChargeState=%d&amp;",    pQuan.iChargeState);
   sprintf(szNewLink+strlen(szNewLink), "OutFile=%s&amp;",        szOutputFile);
   sprintf(szNewLink+strlen(szNewLink), "MassTol=%0.6lf&amp;",    pQuan.dMassTol);
   sprintf(szNewLink+strlen(szNewLink), "bXpressLight1=%d&amp;",    bXpressLight1);
   sprintf(szNewLink+strlen(szNewLink), "InteractDir=%s&amp;",    szInteractDir);
   sprintf(szNewLink+strlen(szNewLink), "InteractBaseName=%s",    szInteractBaseName);

   printf("<FORM METHOD=POST ACTION=\"SetXpressValues.cgi\">");
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightFirstScan\" VALUE=\"%d\">\n", pQuan.iLightFirstScan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightLastScan\" VALUE=\"%d\">\n", pQuan.iLightLastScan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightMass\" VALUE=\"%0.6lf\">\n",pQuan.dLightPeptideMass );
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyFirstScan\" VALUE=\"%d\">\n",pQuan.iHeavyFirstScan );
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyLastScan\" VALUE=\"%d\">\n", pQuan.iHeavyLastScan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyMass\" VALUE=\"%0.6lf\">\n", pQuan.dHeavyPeptideMass);
   printf("<INPUT TYPE=\"hidden\" NAME=\"DatFile\" VALUE=\"%s\">\n", szDatFile);
   printf("<INPUT TYPE=\"hidden\" NAME=\"ChargeState\" VALUE=\"%d\">\n", pQuan.iChargeState);
   printf("<INPUT TYPE=\"hidden\" NAME=\"OutFile\" VALUE=\"%s\">\n", szOutputFile);
   printf("<INPUT TYPE=\"hidden\" NAME=\"MassTol\" VALUE=\"%0.6lf\">\n", pQuan.dMassTol);
   printf("<INPUT TYPE=\"hidden\" NAME=\"bXpressLight1\" VALUE=\"%d\">\n", bXpressLight1);
   printf("<INPUT TYPE=\"hidden\" NAME=\"quantitation_id\" VALUE=\"%d\">\n", pQuan.iquantitation_id);
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightQuanValue\" VALUE=\"%0.1lf\">\n", pQuan.dLightQuanValue);
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyQuanValue\" VALUE=\"%0.1lf\">\n", pQuan.dHeavyQuanValue);
   printf("<INPUT TYPE=\"hidden\" NAME=\"NewLink\" VALUE=\"%s\">\n", szNewLink);
   printf("<INPUT TYPE=\"hidden\" NAME=\"NewQuan\" VALUE=\"%s\">\n", pQuan.szNewQuan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"InteractDir\" VALUE=\"%s\">\n", szInteractDir);
   printf("<INPUT TYPE=\"hidden\" NAME=\"InteractBaseName\" VALUE=\"%s\">\n", szInteractBaseName);
   printf("<INPUT TYPE=\"hidden\" NAME=\"OutputFile\" VALUE=\"%s\">\n", szOutputFile);
   printf("<p><INPUT TYPE=\"submit\" VALUE=\"Update\"></FORM>");

} /*UPDATE_QUAN*/


void BAD_QUAN()
{
   char szBadQuan[4096];  /* Link to bad quantitation */

   printf("<TABLE BORDER=0><TR><TD>");
  /*
   * first quick button for bad quantitation
   */
   sprintf(szBadQuan                  , "LightFirstScan=%d&amp;", pQuan.iLightFirstScan);
   sprintf(szBadQuan+strlen(szBadQuan), "LightLastScan=%d&amp;",  pQuan.iLightFirstScan-1);
   sprintf(szBadQuan+strlen(szBadQuan), "LightMass=%0.6lf&amp;",  pQuan.dLightPeptideMass);
   sprintf(szBadQuan+strlen(szBadQuan), "HeavyFirstScan=%d&amp;", pQuan.iHeavyFirstScan);
   sprintf(szBadQuan+strlen(szBadQuan), "HeavyLastScan=%d&amp;",  pQuan.iHeavyFirstScan-1);
   sprintf(szBadQuan+strlen(szBadQuan), "HeavyMass=%0.6lf&amp;",   pQuan.dHeavyPeptideMass);
   sprintf(szBadQuan+strlen(szBadQuan), "DatFile=%s&amp;",        szDatFile);
   sprintf(szBadQuan+strlen(szBadQuan), "ChargeState=%d&amp;",    pQuan.iChargeState);
   sprintf(szBadQuan+strlen(szBadQuan), "OutFile=%s&amp;",        szOutputFile);
   sprintf(szBadQuan+strlen(szBadQuan), "MassTol=%0.6lf&amp;",    pQuan.dMassTol);
   sprintf(szBadQuan+strlen(szBadQuan), "bXpressLight1=%d&amp;",    bXpressLight1);
   sprintf(szBadQuan+strlen(szBadQuan), "InteractDir=%s&amp;",    szInteractDir);
   sprintf(szBadQuan+strlen(szBadQuan), "InteractBaseName=%s",    szInteractBaseName);

   printf("<FORM METHOD=POST ACTION=\"SetXpressValues.cgi\">");
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightFirstScan\" VALUE=\"%d\">\n", pQuan.iLightFirstScan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightLastScan\" VALUE=\"%d\">\n", pQuan.iLightLastScan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightMass\" VALUE=\"%0.6lf\">\n",pQuan.dLightPeptideMass );
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyFirstScan\" VALUE=\"%d\">\n",pQuan.iHeavyFirstScan );
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyLastScan\" VALUE=\"%d\">\n", pQuan.iHeavyLastScan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyMass\" VALUE=\"%0.6lf\">\n", pQuan.dHeavyPeptideMass);
   printf("<INPUT TYPE=\"hidden\" NAME=\"DatFile\" VALUE=\"%s\">\n", szDatFile);
   printf("<INPUT TYPE=\"hidden\" NAME=\"ChargeState\" VALUE=\"%d\">\n", pQuan.iChargeState);
   printf("<INPUT TYPE=\"hidden\" NAME=\"OutFile\" VALUE=\"%s\">\n", szOutputFile);
   printf("<INPUT TYPE=\"hidden\" NAME=\"MassTol\" VALUE=\"%0.6lf\">\n", pQuan.dMassTol);
   printf("<INPUT TYPE=\"hidden\" NAME=\"bXpressLight1\" VALUE=\"%d\">\n", bXpressLight1);
   printf("<INPUT TYPE=\"hidden\" NAME=\"quantitation_id\" VALUE=\"%d\">\n", pQuan.iquantitation_id);
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightQuanValue\" VALUE=\"%0.1lf\">\n", 0.0);
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyQuanValue\" VALUE=\"%0.1lf\">\n", 0.0);
   printf("<INPUT TYPE=\"hidden\" NAME=\"NewLink\" VALUE=\"%s\">\n", szBadQuan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"NewQuan\" VALUE=\"%s\">\n", "?");
   printf("<INPUT TYPE=\"hidden\" NAME=\"InteractDir\" VALUE=\"%s\">\n", szInteractDir);
   printf("<INPUT TYPE=\"hidden\" NAME=\"InteractBaseName\" VALUE=\"%s\">\n", szInteractBaseName);
   printf("<INPUT TYPE=\"hidden\" NAME=\"OutputFile\" VALUE=\"%s\">\n", szOutputFile);
   printf("<p><INPUT TYPE=\"submit\" VALUE=\"?*\"></FORM>");

   printf("</TD><TD>");

  /*
   * second quick button
   */
   sprintf(szBadQuan                  , "LightFirstScan=%d&amp;", pQuan.iLightFirstScan);
   sprintf(szBadQuan+strlen(szBadQuan), "LightLastScan=%d&amp;",  pQuan.iLightLastScan);
   sprintf(szBadQuan+strlen(szBadQuan), "LightMass=%0.6lf&amp;",  pQuan.dLightPeptideMass);
   sprintf(szBadQuan+strlen(szBadQuan), "HeavyFirstScan=%d&amp;", pQuan.iHeavyFirstScan);
   sprintf(szBadQuan+strlen(szBadQuan), "HeavyLastScan=%d&amp;",  0);
   sprintf(szBadQuan+strlen(szBadQuan), "HeavyMass=%0.6lf&amp;",   pQuan.dHeavyPeptideMass);
   sprintf(szBadQuan+strlen(szBadQuan), "DatFile=%s&amp;",        szDatFile);
   sprintf(szBadQuan+strlen(szBadQuan), "ChargeState=%d&amp;",    pQuan.iChargeState);
   sprintf(szBadQuan+strlen(szBadQuan), "OutFile=%s&amp;",        szOutputFile);
   sprintf(szBadQuan+strlen(szBadQuan), "MassTol=%0.6lf&amp;",    pQuan.dMassTol);
   sprintf(szBadQuan+strlen(szBadQuan), "bXpressLight1=%d&amp;",    bXpressLight1);
   sprintf(szBadQuan+strlen(szBadQuan), "InteractDir=%s&amp;",    szInteractDir);
   sprintf(szBadQuan+strlen(szBadQuan), "InteractBaseName=%s",    szInteractBaseName);

   printf("<FORM METHOD=POST ACTION=\"SetXpressValues.cgi\">");
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightFirstScan\" VALUE=\"%d\">\n", pQuan.iLightFirstScan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightLastScan\" VALUE=\"%d\">\n", pQuan.iLightLastScan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightMass\" VALUE=\"%0.6lf\">\n",pQuan.dLightPeptideMass );
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyFirstScan\" VALUE=\"%d\">\n",pQuan.iHeavyFirstScan );
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyLastScan\" VALUE=\"%d\">\n", pQuan.iHeavyLastScan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyMass\" VALUE=\"%0.6lf\">\n", pQuan.dHeavyPeptideMass);
   printf("<INPUT TYPE=\"hidden\" NAME=\"DatFile\" VALUE=\"%s\">\n", szDatFile);
   printf("<INPUT TYPE=\"hidden\" NAME=\"ChargeState\" VALUE=\"%d\">\n", pQuan.iChargeState);
   printf("<INPUT TYPE=\"hidden\" NAME=\"OutFile\" VALUE=\"%s\">\n", szOutputFile);
   printf("<INPUT TYPE=\"hidden\" NAME=\"MassTol\" VALUE=\"%0.6lf\">\n", pQuan.dMassTol);
   printf("<INPUT TYPE=\"hidden\" NAME=\"bXpressLight1\" VALUE=\"%d\">\n", bXpressLight1);
   printf("<INPUT TYPE=\"hidden\" NAME=\"quantitation_id\" VALUE=\"%d\">\n", pQuan.iquantitation_id);
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightQuanValue\" VALUE=\"%0.1lf\">\n", pQuan.dLightQuanValue);
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyQuanValue\" VALUE=\"%0.1lf\">\n", 0.0);
   printf("<INPUT TYPE=\"hidden\" NAME=\"NewLink\" VALUE=\"%s\">\n", szBadQuan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"NewQuan\" VALUE=\"%s\">\n", "1:0.00");
   printf("<INPUT TYPE=\"hidden\" NAME=\"InteractDir\" VALUE=\"%s\">\n", szInteractDir);
   printf("<INPUT TYPE=\"hidden\" NAME=\"InteractBaseName\" VALUE=\"%s\">\n", szInteractBaseName);
   printf("<INPUT TYPE=\"hidden\" NAME=\"OutputFile\" VALUE=\"%s\">\n", szOutputFile);
   printf("<p><INPUT TYPE=\"submit\" VALUE=\"1:0.00*\"></FORM>");

   printf("</TD><TD>");

  /*
   * third quick button
   */
   sprintf(szBadQuan                  , "LightFirstScan=%d&amp;", pQuan.iLightFirstScan);
   sprintf(szBadQuan+strlen(szBadQuan), "LightLastScan=%d&amp;",  0);
   sprintf(szBadQuan+strlen(szBadQuan), "LightMass=%0.6lf&amp;",  pQuan.dLightPeptideMass);
   sprintf(szBadQuan+strlen(szBadQuan), "HeavyFirstScan=%d&amp;", pQuan.iHeavyFirstScan);
   sprintf(szBadQuan+strlen(szBadQuan), "HeavyLastScan=%d&amp;",  pQuan.iHeavyLastScan);
   sprintf(szBadQuan+strlen(szBadQuan), "HeavyMass=%0.6lf&amp;",   pQuan.dHeavyPeptideMass);
   sprintf(szBadQuan+strlen(szBadQuan), "DatFile=%s&amp;",        szDatFile);
   sprintf(szBadQuan+strlen(szBadQuan), "ChargeState=%d&amp;",    pQuan.iChargeState);
   sprintf(szBadQuan+strlen(szBadQuan), "OutFile=%s&amp;",        szOutputFile);
   sprintf(szBadQuan+strlen(szBadQuan), "MassTol=%0.6lf&amp;",    pQuan.dMassTol);
   sprintf(szBadQuan+strlen(szBadQuan), "bXpressLight1=%d&amp;",    bXpressLight1);
   sprintf(szBadQuan+strlen(szBadQuan), "InteractDir=%s&amp;",    szInteractDir);
   sprintf(szBadQuan+strlen(szBadQuan), "InteractBaseName=%s",    szInteractBaseName);

   printf("<FORM METHOD=POST ACTION=\"SetXpressValues.cgi\">");
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightFirstScan\" VALUE=\"%d\">\n", pQuan.iLightFirstScan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightLastScan\" VALUE=\"%d\">\n", pQuan.iLightLastScan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightMass\" VALUE=\"%0.1lf\">\n",pQuan.dLightPeptideMass );
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyFirstScan\" VALUE=\"%d\">\n",pQuan.iHeavyFirstScan );
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyLastScan\" VALUE=\"%d\">\n", pQuan.iHeavyLastScan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyMass\" VALUE=\"%0.1lf\">\n", pQuan.dHeavyPeptideMass);
   printf("<INPUT TYPE=\"hidden\" NAME=\"DatFile\" VALUE=\"%s\">\n", szDatFile);
   printf("<INPUT TYPE=\"hidden\" NAME=\"ChargeState\" VALUE=\"%d\">\n", pQuan.iChargeState);
   printf("<INPUT TYPE=\"hidden\" NAME=\"OutFile\" VALUE=\"%s\">\n", szOutputFile);
   printf("<INPUT TYPE=\"hidden\" NAME=\"MassTol\" VALUE=\"%0.1lf\">\n", pQuan.dMassTol);
   printf("<INPUT TYPE=\"hidden\" NAME=\"bXpressLight1\" VALUE=\"%d\">\n", bXpressLight1);
   printf("<INPUT TYPE=\"hidden\" NAME=\"quantitation_id\" VALUE=\"%d\">\n", pQuan.iquantitation_id);
   printf("<INPUT TYPE=\"hidden\" NAME=\"LightQuanValue\" VALUE=\"%0.1lf\">\n", 0.0);
   printf("<INPUT TYPE=\"hidden\" NAME=\"HeavyQuanValue\" VALUE=\"%0.1lf\">\n", pQuan.dHeavyQuanValue);
   printf("<INPUT TYPE=\"hidden\" NAME=\"NewLink\" VALUE=\"%s\">\n", szBadQuan);
   printf("<INPUT TYPE=\"hidden\" NAME=\"NewQuan\" VALUE=\"%s\">\n", "0.00:1");
   printf("<INPUT TYPE=\"hidden\" NAME=\"InteractDir\" VALUE=\"%s\">\n", szInteractDir);
   printf("<INPUT TYPE=\"hidden\" NAME=\"InteractBaseName\" VALUE=\"%s\">\n", szInteractBaseName);
   printf("<INPUT TYPE=\"hidden\" NAME=\"OutputFile\" VALUE=\"%s\">\n", szOutputFile);
   printf("<p><INPUT TYPE=\"submit\" VALUE=\"0.00:1*\"></FORM>");

   printf("</TD></TR></TABLE>\n");
} /*BAD_QUAN*/
