<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="html" indent="no"/>
	<xsl:variable name="Affy_home_server">db.systemsbiology.net</xsl:variable>
	<xsl:variable name="Sbeams_server">db.systemsbiology.net</xsl:variable>
	<xsl:variable name="Server">Microarray</xsl:variable>
	
	<xsl:variable name="Base_affy">http://<xsl:value-of select="$Affy_home_server"/>
	</xsl:variable>
	<!-- URL where the XML files will be found -->
	<xsl:variable name="Base_help_url">
		<xsl:value-of select="$Base_affy"/>/Affy_help</xsl:variable>
	<xsl:variable name="Base_sbeams_url">http://<xsl:value-of select="$Sbeams_server"/>/sbeams</xsl:variable>
	<xsl:variable name="Xslt">
		<xsl:value-of select="$Base_help_url"/>/Affy_help.xslt</xsl:variable>
	
	<!-- Name of the php templeate file to add all the transformed data to -->
	<xsl:variable name="Blank_php">isb_help.php</xsl:variable>
	<xsl:template match="/">
		<!-- Add the starting descripition of the page -->
		<xsl:for-each select="./help_document">
			<!-- Start of the Main Page -->
			<h2>
				<xsl:value-of select="@type"/>
			</h2>
			<p class="para">
				<xsl:value-of select="./overview"/>
			</p>
			<br/>
			<!-- Start of the Main Table -->
			<xsl:for-each select="all_summaries">
				<foo/>
				<xsl:for-each select="summary">
					<!-- Add name anchor tags so all summary nodes can be linked to -->
					<a name="{./name}"/>
					<!-- Start a  table to hold each chunk of summary Data -->
					<table>
						<!-- Each summary Has two rows with two cells each, Description on the left Link or images on the right -->
						<tr>
							<td background="images/fade_orange_header_2.png" class="nav_sub" colspan="2">
								<xsl:value-of select="./name"/>
							</td>
						</tr>
						<tr>
							<!-- Add the description text -->
							<td align="Left" class="desc_cell">
								<b>
									<xsl:value-of select="description"/>
								</b>
								<!-- If there are steps make a table to hold them -->
								<xsl:for-each select="./all_steps">
									<br/>
									<br/>
									<table align="left">
										<xsl:for-each select="./step">
											<tr>
												<td class="numb_cell">
													<xsl:number level="single" format="1)"/>
												</td>
												<td>
													<xsl:value-of select="./text()"/>
													<br/>
													<!-- Check to see if the node has any link_info nodes -->
													<xsl:for-each select="./link_info">
														<xsl:call-template name="format_link">
															<xsl:with-param name="has_desc" select="'NO'"/>
														</xsl:call-template>
													</xsl:for-each>
												</td>
											</tr>
											<tr>
												<!-- if we have some computer code to show print it out -->
												<xsl:for-each select="./code">
													<tr>
														<td> </td>
														<td class="code_cell">
															<pre>
																<xsl:copy-of select="."/>
															</pre>
														</td>
													</tr>
												</xsl:for-each>
											</tr>
										</xsl:for-each>
									</table>
								</xsl:for-each>
							</td>
							<!-- close first cell of summary Row -->
							<!-- Seconds Cell Holds link or images -->
							<td class="extra_cell">
								<!-- If this is link node make a link -->
								<xsl:for-each select="./extra_data[@data_type='link']">
									<xsl:for-each select="./link_info">
										<xsl:call-template name="format_link">
											<xsl:with-param name="has_desc" select="'YES'"/>
										</xsl:call-template>
									</xsl:for-each>
								</xsl:for-each>
								<!-- If this is image node bring in the image -->
								<xsl:for-each select="./extra_data[@data_type='image']">
									<xsl:for-each select="./image">
										<xsl:call-template name="format_image">
											<xsl:with-param name="has_desc" select="'YES'"/>
										</xsl:call-template>
									</xsl:for-each>
								</xsl:for-each>
								<!-- Look for any table info -->
								<xsl:for-each select="./table_info">
									<xsl:choose>
										<xsl:when test="//entry[string-length() &gt; 100]">
											<tr>
												<td colspan="2">
													<xsl:call-template name="make_table"/>
												</td>
											</tr>
										</xsl:when>
										<xsl:otherwise>
											<xsl:call-template name="make_table"/>
										</xsl:otherwise>
									</xsl:choose>
								</xsl:for-each>
							</td>
						</tr>
					</table>
				</xsl:for-each>
				<!-- End summary foreach loop -->
			</xsl:for-each>
			<!-- End all_summaries foreach loop -->
		</xsl:for-each>
		<!-- End help_document foreach loop -->
	</xsl:template>
	<!-- ################## template to format the info within link_info nodes #################### -->
	<xsl:template name="format_link">
		<xsl:param name="has_desc" select="false()"/>
		<table align="left">
			<xsl:choose>
				<!-- Look to see if a link is present -->
				<xsl:when test="@type = 'internal_help'">
					<!-- Only output description cell if there is one, or should be one -->
					<xsl:if test="$has_desc">
						<tr>
							<td class="table_header">
								<xsl:value-of select="preceding-sibling::description"/>
							</td>
						</tr>
					</xsl:if>
					<tr>
						<td class="Nav_link">
							<a href="{$Blank_php}?help_page={@href}" target="win-2">
								<xsl:value-of select="."/>
							</a>
						</td>
					</tr>
				</xsl:when>
				<xsl:when test="@type = 'sbeams_page'">
					<xsl:if test="$has_desc">
						<tr>
							<td class="table_header">
								<xsl:value-of select="../description"/>
							</td>
						</tr>
					</xsl:if>
					<tr>
						<td class="Nav_link">
							<a href="{$Base_sbeams_url}/{@href}" target="win-2">
								<xsl:value-of select="."/>
							</a>
						</td>
					</tr>
				</xsl:when>
		<!-- Otherwise just output the URL if there is one -->
				<xsl:otherwise>
					<xsl:if test="$has_desc">
						<tr>
							<td class="table_header">
								<xsl:value-of select="../description"/>
							</td>
						</tr>
					</xsl:if>
					<tr>
						<td class="Nav_link">
							<a href="{@href}" target="win-2">
								<xsl:value-of select="."/>
							</a>
						</td>
					</tr>
				</xsl:otherwise>
			</xsl:choose>
		</table>
	</xsl:template>
	<!-- ############################# Format image ################################# -->
	<xsl:template name="format_image">
		<xsl:param name="has_desc" select="false()"/>
		<xsl:param name="map_name" >#<xsl:value-of select="./map_info/map/@name"/></xsl:param>
		<xsl:if test="./map_info">
	 <xsl:copy-of select="//map"/>
	</xsl:if>
		<xsl:choose>
			<!-- Look to see if a link is present -->
			<xsl:when test="@type = 'internal_help'">
				<!-- Only output description cell if there is one, or should be one -->
				<xsl:if test="$has_desc">
					<b>
						<xsl:value-of select="preceding-sibling::description"/>
					</b>
					<br/>
				</xsl:if>
				<xsl:choose>
					<xsl:when test="@width &lt; 300">
						<!-- if large image is detected it will produce the image on the next line down to try and prevent the image from screwing up the page -->
						<img src="./Affy_help/images/{@src}" width="{@width}" height="{@height}" alt="Image could not be found" usemap="{$map_name}" border='0' />
					</xsl:when>
					<xsl:otherwise>
						<tr>
							<td colspan="2">
								<img src="./Affy_help/images/{@src}" width="{@width}" height="{@height}" alt="Image could not be found" usemap="{$map_name}" border='0'/>
							</td>
						</tr>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:when>
			<!-- Otherwise just output the image using the full href provided by the user if there is one -->
			<xsl:otherwise>
				<xsl:choose>
					<xsl:when test="@width>300">
						<!-- if large image is detected it will produce the image on the next line down to try and prevent the image from screwing up the page -->
						<tr>
							<td colspan="2">
								<img src="{@src}" width="{@width}" height="{@height}" alt="Image could not be found" usemap="{$map_name}" border='0'/>
							</td>
						</tr>
					</xsl:when>
					<xsl:otherwise>
						<img src="{@src}" width="{@width}" height="{@height}" alt="Image could not be found" usemap="{$map_name}" border='0'/>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:otherwise>
		</xsl:choose>
	
	
	</xsl:template>
	<!-- #################### Format Table template ########################## -->
	<xsl:template name="make_table">
		<TABLE border="1">
			<!-- Put the sections headers in a table row at the top of the table -->
			<TR>
				<xsl:apply-templates select="section"/>
			</TR>
			<!-- Produce the table rows that contain
     the actual entries. This is a function call of the template
     with 'name' rowCounter, called with a parameter of 1, i.e.
     rowCounter(1). -->
			<xsl:call-template name="rowCounter">
				<xsl:with-param name="N" select="1"/>
			</xsl:call-template>
		</TABLE>
	</xsl:template>
	<xsl:template name="rowCounter">
		<xsl:param name="N"/>
		<!-- If there are any entries in any section 
    with a  position number of $N then we produce a
    new table row -->
		<xsl:if test="section/entry[ $N ]">
			<TR>
				<!-- We produce a TD for each section, 
       which contains a processed entry if there was an
       N-th entry in the section. -->
				<xsl:for-each select="section">
					<TD>
						<xsl:apply-templates select="entry[ $N ]"/>
						<xsl:text> </xsl:text>
						<!-- This space is needed to stop us
            getting empty TD elements which XT outputs as <TD/> which
	     Netscape doesn't like. -->
					</TD>
				</xsl:for-each>
			</TR>
			<!-- The recursive call for the next larger value of N -->
			<xsl:call-template name="rowCounter">
				<xsl:with-param name="N" select="$N + 1"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>
	<xsl:template match="section">
		<TH>
			<xsl:value-of select="@name"/>
		</TH>
	</xsl:template>
</xsl:stylesheet>
