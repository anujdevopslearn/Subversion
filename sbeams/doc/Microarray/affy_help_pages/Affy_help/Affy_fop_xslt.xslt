<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.1" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format" exclude-result-prefixes="fo">
  <xsl:output method="xml" version="1.0" omit-xml-declaration="no" indent="yes"/>
 
<!-- VARIABLES -->
  <xsl:variable name="Affy_home_server">db.systemsbiology.net</xsl:variable>
	<xsl:variable name="Sbeams_server">db.systemsbiology.net</xsl:variable>
	<xsl:variable name="Server">Microarray</xsl:variable>
	<xsl:variable name="Tomcat_server">http://10.0.1.114:8080/xalanservlet/xalan_transform_dev.jsp?PMA=foo&amp;</xsl:variable>
	<xsl:variable name="Base_affy">http://<xsl:value-of select="$Affy_home_server"/>
	</xsl:variable>
	<!-- URL where the XML files will be found -->
	<xsl:variable name="Base_help_url">
		<xsl:value-of select="$Base_affy"/>/Affy_help</xsl:variable>
	<xsl:variable name="Base_sbeams_url">http://<xsl:value-of select="$Sbeams_server"/>/sbeams</xsl:variable>
	<xsl:variable name="Xslt">
		<xsl:value-of select="$Base_help_url"/>/Affy_help.xslt</xsl:variable>
	<xsl:variable name="Xalanjsp_url">
		<xsl:value-of select="$Tomcat_server"/>XSL=<xsl:value-of select="$Xslt"/>
	</xsl:variable>
	<!-- Name of the php templeate file to add all the transformed data to -->
	<xsl:variable name="Blank_php">isb_help.php</xsl:variable>

  
  
  <!-- ========================= -->
  <!-- root element:help_document  -->
  <!-- ========================= -->
  <xsl:template match="help_document ">
    <fo:root xmlns:fo="http://www.w3.org/1999/XSL/Format">
      <fo:layout-master-set>
        <fo:simple-page-master master-name="simpleA4" page-height="29.7cm" page-width="21cm" margin-top="2cm" margin-bottom="2cm" margin-left="2cm" margin-right="2cm">
          <fo:region-body/>
        </fo:simple-page-master>
      </fo:layout-master-set>
      <!-- Start page-sequence -->
      <fo:page-sequence master-reference="simpleA4">
        <fo:flow flow-name="xsl-region-body">
          <fo:block font-size="22pt" font-weight="bold" space-after="5mm">Page Info: <xsl:value-of select="@type"/>
          </fo:block>
      
        <xsl:apply-templates/>
           </fo:flow>
      </fo:page-sequence>
    </fo:root>
  </xsl:template>
  <!-- ========================= -->
  <!-- template : summary     -->
  <!-- ========================= -->
 <!-- <fo:leader leader-pattern="rule" rule-style="grooved"/> -->
 
  <xsl:template match="all_summaries">
   <!-- Print out header for all_summaries -->
    <fo:block font-size="20pt" line-height="23pt">
     	<xsl:value-of select="./overview"/>
    </fo:block>

<!-- Loop Throught the summary nodes -->
    <xsl:for-each select="summary">
    	
    	<!-- Print out Name header for all summaries -->
    	<fo:block font-size="18pt" line-height="21pt" background-color="#EEEEEE" space-after="3mm">
     		Summary Name: <xsl:value-of select="./name"/>
    	</fo:block>
    	<!-- Print out Description header for all summaries -->
    	<fo:block font-size="17pt" line-height="20pt"  space-after="3mm">
     		<xsl:value-of select="./description"/>
    	<fo:leader leader-pattern="rule"  leader-length='20pt' rule-style="groove"/>
    	
    	<xsl:for-each select="./extra_data[@data_type='image']">
									<xsl:for-each select="./image">
										<xsl:call-template name="format_image">
											<xsl:with-param name="has_desc" select="'YES'"/>
										</xsl:call-template>
									</xsl:for-each>
	</xsl:for-each>
    
    	
    	
    	</fo:block>
    	
    	
    	
    	


    
    </xsl:for-each>
 <!-- #################### FORMAT IMAGE TEMPLATE    ############################## -->
      </xsl:template>
      <xsl:template name="format_image">
      	<xsl:param name="has_desc" select="false()"/>

			<xsl:if test="@width>300">
					<!-- if large image is detected it will produce the image on the next line down to try and prevent the image from screwing up the page -->
					<fo:block  border-style="dotted" border-width="thin">
						<img src=".ima{@src}" width="{@width}" height="{@height}" alt="Image could not be found"/>
					</fo:block>
			</xsl:if>
			
				<xsl:when test="@type = 'internal_help'">
				<!-- Only output description cell if there is one, or should be one -->
				<fo:block  border-style="dotted" border-width="thin">
				<xsl:if test="@width>300">
					<fo:external-graphic src=".image/{@src}" width="{@width}" height="{@height}"/>
				</xsl:if>
				<xsl:if test="@width<300">
					<fo:external-graphic src="./images/{@src}"/> 			
				</xsl:if>
					<xsl:if test="$has_desc">
						<xsl:value-of select="preceding-sibling::description"/>
					</xsl:if>
				</fo:block>
		

	</xsl:template>
      
</xsl:stylesheet>
