<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:mml="http://www.w3.org/1998/Math/MathML"
	xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math">
	<xsl:output method="xml" encoding="UTF-8" />

	<!-- %%Template: match *

		The catch all template, just passes through
	-->
	<xsl:template match="*">
		<xsl:apply-templates select="*" />
	</xsl:template>

	<!-- %%Template: match *

		Another catch all template, just passes through
	-->
	<xsl:template match="/">
		<m:oMath>
			<xsl:apply-templates select="*" />
		</m:oMath>
	</xsl:template>

	<!-- %%Template: SReplace

		Replace all occurences of sOrig in sInput with sReplacement
		and return the resulting string. -->
	<xsl:template name="SReplace">
		<xsl:param name="sInput" />
		<xsl:param name="sOrig" />
		<xsl:param name="sReplacement" />

		<xsl:choose>
			<xsl:when test="not(contains($sInput, $sOrig))">
				<xsl:value-of select="$sInput" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:variable name="sBefore" select="substring-before($sInput, $sOrig)" />
				<xsl:variable name="sAfter" select="substring-after($sInput, $sOrig)" />
				<xsl:variable name="sAfterProcessed">
					<xsl:call-template name="SReplace">
						<xsl:with-param name="sInput" select="$sAfter" />
						<xsl:with-param name="sOrig" select="$sOrig" />
						<xsl:with-param name="sReplacement" select="$sReplacement" />
					</xsl:call-template>
				</xsl:variable>

				<xsl:value-of select="concat($sBefore, concat($sReplacement, $sAfterProcessed))" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- %%Template: OutputText

		Post processing on the string given and otherwise do
		a xsl:value-of on it -->
	<xsl:template name="OutputText">
		<xsl:param name="sInput" />

		<!-- Add local variable as you add new post processing tasks -->

		<!-- 1. Remove any unwanted characters -->
		<xsl:variable name="sCharStrip">
			<xsl:value-of select="translate($sInput, '&#x2062;&#x200B;', '')" />
		</xsl:variable>

		<!-- 2. Replace any characters as needed -->
		<!--	Replace &#x2A75; <-> ==			 -->
		<xsl:variable name="sCharReplace">
			<xsl:call-template name="SReplace">
				<xsl:with-param name="sInput" select="$sCharStrip" />
				<xsl:with-param name="sOrig" select="'&#x2A75;'" />
				<xsl:with-param name="sReplacement" select="'=='" />
			</xsl:call-template>
		</xsl:variable>

		<!-- Finally, return the last value -->
		<xsl:value-of select="$sCharReplace" />
	</xsl:template>

	<!-- %%Template: mrow|mml:mstyle

		 if this row is the next sibling of an n-ary (i.e. any of
         mover, munder, munderover, msupsub, msup, or msub with
         the base being an n-ary operator) then ignore this. Otherwise
         pass through -->
	<xsl:template match="mml:mrow|mml:mstyle">
		<xsl:choose>
			<xsl:when test="preceding-sibling::*[1][self::mml:munder or self::mml:mover or self::mml:munderover or
                                                    self::mml:msub or self::mml:msup or self::mml:msubsup]">
				<xsl:variable name="fNary">
					<xsl:call-template name="isNary">
						<xsl:with-param name="ndCur" select="preceding-sibling::*[1]/child::*[1]" />
					</xsl:call-template>
				</xsl:variable>
				<xsl:if test="not($fNary = 'true')">
					<xsl:apply-templates />
				</xsl:if>
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template match="mml:mi[not(child::mml:mglyph)] |
	                     mml:mn[not(child::mml:mglyph)] |
	                     mml:mo[not(child::mml:mglyph)] |
	                     mml:ms[not(child::mml:mglyph)] |
	                     mml:mtext[not(child::mml:mglyph)]">

		<!-- tokens with mglyphs as children are tranformed
			 in a different manner than "normal" token elements.
			 Where normal token elements are token elements that
			 contain only text -->
		<xsl:variable name="fStartOfRun"
					select="count(preceding-sibling::*)=0 or
					preceding-sibling::*[1][not(self::mml:mi[not(child::mml:mglyph)]) and
					not(self::mml:mn[not(child::mml:mglyph)]) and
					not(self::mml:mo[not(child::mml:mglyph)]) and
					not(self::mml:ms[not(child::mml:mglyph)]) and
					not(self::mml:mtext[not(child::mml:mglyph)])]" />

		<!--In MathML, successive characters that are all part of one string are sometimes listed as separate
			tags based on their type (identifier (mi), name (mn), operator (mo), quoted (ms), literal text (mtext)),
			where said tags act to link one another into one logical run.  In order to wrap the text of successive mi's,
			mn's, and mo's into one m:t, we need to denote where a run begins.  The beginning of a run is the first mi, mn,
			or mo whose immediately preceding sibling either doesn't exist or is something other than a "normal" mi, mn, mo,
			ms, or mtext tag-->
		<xsl:variable name="fShouldCollect"
					select="parent::mml:mrow or parent::mml:mstyle or
					parent::mml:msqrt or parent::mml:menclose or
					parent::mml:math or parent::mml:mphantom or
					parent::mml:mtd" />

		<!--In MathML, the meaning of the different parts that make up mathematical structures, such as a fraction
			having a numerator and a denominator, is determined by the relative order of those different parts.
			For instance, In a fraction, the numerator is the first child and the denominator is the second child.
			To allow for more complex structures, MathML allows one to link a group of mi, mn, and mo's together
			using the mrow, or mstyle tags.  The mi, mn, and mo's found within any of the above tags are considered
			one run.  Therefore, if the parent of any mi, mn, or mo is found to be an mrow or mstyle, then the contiguous
			mi, mn, and mo's will be considered one run.-->
		<xsl:choose>
			<xsl:when test="$fShouldCollect">
				<xsl:choose>
					<xsl:when test="$fStartOfRun">
						<!--If this is the beginning of the run, pass all run attributes to CreateRunWithSameProp.-->
						<xsl:call-template name="CreateRunWithSameProp">
							<xsl:with-param name="mathbackground" select="@mathbackground" />
							<xsl:with-param name="mathcolor" select="@mathcolor" />
							<xsl:with-param name="mathvariant" select="@mathvariant" />
							<xsl:with-param name="color" select="@color" />
							<xsl:with-param name="font-family" select="@font-family" />
							<xsl:with-param name="fontsize" select="@fontsize" />
							<xsl:with-param name="fontstyle" select="@fontstyle" />
							<xsl:with-param name="fontweight" select="@fontweight" />
							<xsl:with-param name="mathsize" select="@mathsize" />
							<xsl:with-param name="ndTokenFirst" select="." />
						</xsl:call-template>
					</xsl:when>
				</xsl:choose>
			</xsl:when>
			<xsl:otherwise>
				<!--Only one element will be part of run-->
				<xsl:element name="m:r">
					<!--Create Run Properties based on current node's attributes-->
					<xsl:call-template name="CreateRunProp">
						<xsl:with-param name="mathvariant" select="@mathvariant" />
						<xsl:with-param name="fontstyle" select="@fontstyle" />
						<xsl:with-param name="fontweight" select="@fontweight" />
						<xsl:with-param name="mathcolor" select="@mathcolor" />
						<xsl:with-param name="mathsize" select="@mathsize" />
						<xsl:with-param name="color" select="@color" />
						<xsl:with-param name="fontsize" select="@fontsize" />
						<xsl:with-param name="ndCur" select="." />
					</xsl:call-template>
					<xsl:element name="m:t">
						<xsl:call-template name="OutputText">
							<xsl:with-param name="sInput" select="normalize-space(.)" />
						</xsl:call-template>
					</xsl:element>
				</xsl:element>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- %%Template: CreateRunWithSameProp
	-->
	<xsl:template name="CreateRunWithSameProp">
		<xsl:param name="mathbackground" />
		<xsl:param name="mathcolor" />
		<xsl:param name="mathvariant" />
		<xsl:param name="color" />
		<xsl:param name="font-family" />
		<xsl:param name="fontsize" />
		<xsl:param name="fontstyle" />
		<xsl:param name="fontweight" />
		<xsl:param name="mathsize" />
		<xsl:param name="ndTokenFirst" />

		<!--Given mathcolor, color, mstyle's (ancestor) color, and precedence of
			said attributes, determine the actual color of the current run-->
		<xsl:variable name="sColorPropCur">
			<xsl:choose>
				<xsl:when test="$mathcolor!=''">
					<xsl:value-of select="$mathcolor" />
				</xsl:when>
				<xsl:when test="$color!=''">
					<xsl:value-of select="$color" />
				</xsl:when>
				<xsl:when test="$ndTokenFirst/ancestor::mml:mstyle[@color][1]/@color!=''">
					<xsl:value-of select="$ndTokenFirst/ancestor::mml:mstyle[@color][1]/@color" />
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="''" />
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<!--Given mathsize, and fontsize and precedence of said attributes,
			determine the actual font size of the current run-->
		<xsl:variable name="sSzCur">
			<xsl:choose>
				<xsl:when test="$mathsize!=''">
					<xsl:value-of select="$mathsize" />
				</xsl:when>
				<xsl:when test="$fontsize!=''">
					<xsl:value-of select="$fontsize" />
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="''" />
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<!--Given mathvariant, fontstyle, and fontweight, and precedence of
			the attributes, determine the actual font of the current run-->
		<xsl:variable name="sFontCur">
			<xsl:call-template name="GetFontCur">
				<xsl:with-param name="mathvariant" select="$mathvariant" />
				<xsl:with-param name="fontstyle" select="$fontstyle" />
				<xsl:with-param name="fontweight" select="$fontstyle" />
				<xsl:with-param name="ndCur" select="$ndTokenFirst" />
			</xsl:call-template>
		</xsl:variable>

		<!--In order to determine the length of the run, we will find the number of nodes before the inital node in the run and
			the number of nodes before the first node that DOES NOT belong to the current run.  The number of nodes that will
			be printed is One Less than the difference between the latter and the former-->

		<!--Find index of current node-->
		<xsl:variable name="nndBeforeFirst" select="count($ndTokenFirst/preceding-sibling::*)" />

		<!--Find index of next change in run properties-->
		<xsl:variable name="nndBeforeLim" select="count($ndTokenFirst/following-sibling::*
					[(not(self::mml:mi) and not(self::mml:mn) and not(self::mml:mo) and not(self::mml:ms) and not(self::mml:mtext))
					or
					(self::mml:mi[child::mml:mglyph] or self::mml:mn[child::mml:mglyph] or self::mml:mo[child::mml:mglyph] or self::mml:ms[child::mml:mglyph] or self::mml:mtext[child::mml:mglyph])
					or
					not(
						(($mathbackground=@mathbackground) or
							((not(@mathbackground) or $mathbackground) and (not($mathbackground) or $mathbackground=''))
						)
						and
						(($sColorPropCur=@mathcolor) or
							((not(@mathcolor) or @mathcolor='') and $sColorPropCur=@color) or
							((not(@mathcolor) or @mathcolor='') and (not(@color) or @color='') and ancestor::mml:mstyle[@color][1]/@color=$sColorPropCur) or
							((not(@mathcolor) or @mathcolor='') and (not(@color) or @color='') and (not(ancestor::mml:mstyle[@color][1]/@color) or ancestor::mml:mstyle[@color][1]/@color='') and (not($sColorPropCur) or $sColorPropCur=''))
						)
						and
						(($sSzCur=@mathsize) or
							((not(@mathsize) or @mathsize='') and $sSzCur=@fontsize) or
							((not(@mathsize) or @mathsize='') and (not(@fontsize) or @fontsize='') and (not($sSzCur) or $sSzCur=''))
						)
						and
						((($sFontCur=@mathvariant)
							or
							((not(@mathvariant) or @mathvariant='') and ($sFontCur='normal') and (not(self::mml:mi)                                   or
																								(@fontstyle='normal' and (not(@fontweight='bold'))) or
																								(string-length(normalize-space(.)) &gt; 1)
																								))
							or
							((not(@mathvariant) or @mathvariant='') and ($sFontCur='bi') and (@fontstyle='italic' and @fontweight='bold'))
							or
							(($sFontCur='italic') and (((not(@mathvariant) or @mathvariant='') and
															(
															(@fontstyle='italic' and
															(@fontweight='normal' or not(@fontweight) or @fontweight='')
															)
															or
															((not(@fontstyle) or @fontstyle='') and (not(@fontweight)=@fontweight=''))
															)
														) or @mathvariant='italic'
														)
							)
							or
							(($sFontCur='bold') and (((not(@mathvariant) or @mathvariant='') and @fontweight='bold' and (@fontstyle='normal' or not(@fontstyle) or @fontstyle='')) or @mathvariant='bold'))
							or
							(($sFontCur='' and (((not(@mathvariant) or @mathvariant='') and (not(@fontstyle) or @fontstyle='') and (not(@fontweight)or @fontweight='')) or
													(@mathvariant='italic')                                      or
													((not(@mathvariant) or @mathvariant='') and @fontweight='normal' and @fontstyle='italic') or
													((not(@mathvariant) or @mathvariant='') and (not(@fontweight) or @fontweight='') and @fontstyle='italic')       or
													((not(@mathvariant) or @mathvariant='') and (not(@fontweight) or @fontweight='') and (not(@fontstyle) or @fontweight=''))
												)
							))
							or
							($sFontCur='normal' and

							(self::mml:mi and
							(not(@mathvariant) or @mathvariant='') and
							(not(@fontstyle) or @fontstyle='') and
							(not(@fontweight) or @fontweight='') and
							string-length(normalize-space(.)) &gt; 1
							)
							or
							( (self::mml:ms or self::mml:mtext) and
								(not(@mathvariant) or @mathvariant='') and
								(not(@fontstyle) or @fontstyle) and
								(not(@fontweight) or @fontweight)
							)
							))
							and not( (not(@mathvariant) or @mathvariant='') and
									(not(@fontstyle) or @fontstyle='') and
									(not(@fontweight) or @fontweight='') and
									((self::mml:mi and (string-length(normalize-space(.)) &gt; 1)) or self::mml:ms or self::mml:mtext) and
									($sFontCur!='normal') )
						)
						and
						(($font-family=@font-family) or
							((not(@font-family) or @font-family) and (not($font-family) or $font-family=''))
						)
						)
					][1]/preceding-sibling::*)" />

		<xsl:variable name="cndRun" select="$nndBeforeLim - $nndBeforeFirst" />

		<!--Contiguous groups of like-property mi, mn, and mo's are separated by non- mi, mn, mo tags, or mi,mn, or mo
			tags with different properties.  nndBeforeLim is the number of nodes before the next tag which separates contiguous
			groups of like-property mi, mn, and mo's.  Knowing this delimiting tag allows for the aggregation of the correct
			number of mi, mn, and mo tags.-->
		<xsl:element name="m:r">

			<!--The beginning and ending of the current run has been established. Now we should open a run element-->
			<xsl:choose>

					<!--If cndRun > 0, then there is a following diffrent prop, or non- Token,
						although there may or may not have been a preceding different prop, or non-
						Token-->
				<xsl:when test="$cndRun &gt; 0">
					<xsl:call-template name="CreateRunProp">
						<xsl:with-param name="mathvariant" select="$mathvariant" />
						<xsl:with-param name="fontstyle" select="$fontstyle" />
						<xsl:with-param name="fontweight" select="$fontweight" />
						<xsl:with-param name="mathcolor" select="$mathcolor" />
						<xsl:with-param name="mathsize" select="$mathsize" />
						<xsl:with-param name="color" select="$color" />
						<xsl:with-param name="fontsize" select="$fontsize" />
						<xsl:with-param name="ndCur" select="$ndTokenFirst" />
					</xsl:call-template>
					<xsl:element name="m:t">
						<xsl:call-template name="OutputText">
							<xsl:with-param name="sInput">
								<xsl:choose>
									<xsl:when test="namespace-uri($ndTokenFirst) = 'http://www.w3.org/1998/Math/MathML' and local-name($ndTokenFirst) = 'ms'">
										<xsl:call-template name="OutputMs">
											<xsl:with-param name="msCur" select="$ndTokenFirst" />
										</xsl:call-template>
									</xsl:when>
									<xsl:otherwise>
										<xsl:value-of select="normalize-space($ndTokenFirst)" />
									</xsl:otherwise>
								</xsl:choose>
								<xsl:for-each select="$ndTokenFirst/following-sibling::*[position() &lt; $cndRun]">
									<xsl:choose>
										<xsl:when test="namespace-uri(.) = 'http://www.w3.org/1998/Math/MathML' and
													local-name(.) = 'ms'">
											<xsl:call-template name="OutputMs">
												<xsl:with-param name="msCur" select="." />
											</xsl:call-template>
										</xsl:when>
										<xsl:otherwise>
											<xsl:value-of select="normalize-space(.)" />
										</xsl:otherwise>
									</xsl:choose>
								</xsl:for-each>
							</xsl:with-param>
						</xsl:call-template>
					</xsl:element>
				</xsl:when>
				<xsl:otherwise>

					<!--if cndRun lt;= 0, then iNextNonToken = 0,
						and iPrecNonToken gt;= 0.  In either case, b/c there
						is no next different property or non-Token
						(which is implied by the nndBeforeLast being equal to 0)
						you can put all the remaining mi, mn, and mo's into one
						group.-->
					<xsl:call-template name="CreateRunProp">
						<xsl:with-param name="mathvariant" select="$mathvariant" />
						<xsl:with-param name="fontstyle" select="$fontstyle" />
						<xsl:with-param name="fontweight" select="$fontweight" />
						<xsl:with-param name="mathcolor" select="$mathcolor" />
						<xsl:with-param name="mathsize" select="$mathsize" />
						<xsl:with-param name="color" select="$color" />
						<xsl:with-param name="fontsize" select="$fontsize" />
						<xsl:with-param name="ndCur" select="$ndTokenFirst" />
					</xsl:call-template>
					<xsl:element name="m:t">

						<!--Create the Run, first output current, then in a
							for-each, because all the following siblings are
							mn, mi, and mo's that conform to the run's properties,
							group them together-->
						<xsl:call-template name="OutputText">
							<xsl:with-param name="sInput">
								<xsl:choose>
									<xsl:when test="namespace-uri($ndTokenFirst) = 'http://www.w3.org/1998/Math/MathML' and
													local-name($ndTokenFirst) = 'ms'">
										<xsl:call-template name="OutputMs">
											<xsl:with-param name="msCur" select="$ndTokenFirst" />
										</xsl:call-template>
									</xsl:when>
									<xsl:otherwise>
										<xsl:value-of select="normalize-space($ndTokenFirst)" />
									</xsl:otherwise>
								</xsl:choose>
								<xsl:for-each select="$ndTokenFirst/following-sibling::*[self::mml:mi or self::mml:mn or self::mml:mo or self::mml:ms or self::mml:mtext]">
									<xsl:choose>
										<xsl:when test="namespace-uri(.) = 'http://www.w3.org/1998/Math/MathML' and
													local-name(.) = 'ms'">
											<xsl:call-template name="OutputMs">
												<xsl:with-param name="msCur" select="." />
											</xsl:call-template>
										</xsl:when>
										<xsl:otherwise>
											<xsl:value-of select="normalize-space(.)" />
										</xsl:otherwise>
									</xsl:choose>
								</xsl:for-each>
							</xsl:with-param>
						</xsl:call-template>
					</xsl:element>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:element>

			<!--The run was terminated by an mi, mn, or mo with different properties, therefore,
				call-template CreateRunWithSameProp, using cndRun+1 node as new start node-->
		<xsl:if test="$nndBeforeLim!=0 and
					namespace-uri($ndTokenFirst/following-sibling::*[$cndRun])='http://www.w3.org/1998/Math/MathML' and
					(local-name($ndTokenFirst/following-sibling::*[$cndRun])='mi' or
					local-name($ndTokenFirst/following-sibling::*[$cndRun])='mn' or
					local-name($ndTokenFirst/following-sibling::*[$cndRun])='mo' or
					local-name($ndTokenFirst/following-sibling::*[$cndRun])='ms' or
					local-name($ndTokenFirst/following-sibling::*[$cndRun])='mtext') and
					(count($ndTokenFirst/following-sibling::*[$cndRun]/mml:mglyph) = 0)">
			<xsl:call-template name="CreateRunWithSameProp">
				<xsl:with-param name="mathbackground" select="$ndTokenFirst/following-sibling::*[$cndRun]/@mathbackground" />
				<xsl:with-param name="mathcolor" select="$ndTokenFirst/following-sibling::*[$cndRun]/@mathcolor" />
				<xsl:with-param name="mathvariant" select="$ndTokenFirst/following-sibling::*[$cndRun]/@mathvariant" />
				<xsl:with-param name="color" select="$ndTokenFirst/following-sibling::*[$cndRun]/@color" />
				<xsl:with-param name="font-family" select="$ndTokenFirst/following-sibling::*[$cndRun]/@font-family" />
				<xsl:with-param name="fontsize" select="$ndTokenFirst/following-sibling::*[$cndRun]/@fontsize" />
				<xsl:with-param name="fontstyle" select="$ndTokenFirst/following-sibling::*[$cndRun]/@fontstyle" />
				<xsl:with-param name="fontweight" select="$ndTokenFirst/following-sibling::*[$cndRun]/@fontweight" />
				<xsl:with-param name="mathsize" select="$ndTokenFirst/following-sibling::*[$cndRun]/@mathsize" />
				<xsl:with-param name="ndTokenFirst" select="$ndTokenFirst/following-sibling::*[$cndRun]" />
			</xsl:call-template>
		</xsl:if>
	</xsl:template>

	<!-- %%Template: CreateRunProp
	-->
	<xsl:template name="CreateRunProp">
		<xsl:param name="mathbackground" />
		<xsl:param name="mathcolor" />
		<xsl:param name="mathvariant" />
		<xsl:param name="color" />
		<xsl:param name="font-family" />
		<xsl:param name="fontsize" />
		<xsl:param name="fontstyle" />
		<xsl:param name="fontweight" />
		<xsl:param name="mathsize" />
		<xsl:param name="ndCur" />
		<xsl:param name="fontfamily" />
		<xsl:variable name="mstyleColor">
			<xsl:if test="not(not($ndCur))">
				<xsl:value-of select="$ndCur/ancestor::mml:mstyle[@color][1]/@color" />
			</xsl:if>
		</xsl:variable>
		<xsl:call-template name="CreateMathRPR">
			<xsl:with-param name="mathvariant" select="$mathvariant" />
			<xsl:with-param name="fontstyle" select="$fontstyle" />
			<xsl:with-param name="fontweight" select="$fontweight" />
			<xsl:with-param name="ndCur" select="$ndCur" />
		</xsl:call-template>
	</xsl:template>

	<!-- %%Template: CreateMathRPR
	-->
	<xsl:template name="CreateMathRPR">
		<xsl:param name="mathvariant" />
		<xsl:param name="fontstyle" />
		<xsl:param name="fontweight" />
		<xsl:param name="ndCur" />
		<xsl:variable name="sFontCur">
			<xsl:call-template name="GetFontCur">
				<xsl:with-param name="mathvariant" select="$mathvariant" />
				<xsl:with-param name="fontstyle" select="$fontstyle" />
				<xsl:with-param name="fontweight" select="$fontstyle" />
				<xsl:with-param name="ndCur" select="$ndCur" />
			</xsl:call-template>
		</xsl:variable>
		<xsl:if test="$sFontCur!='italic' and $sFontCur!=''">
			<xsl:call-template name="CreateMathScrStyProp">
				<xsl:with-param name="font" select="$sFontCur" />
			</xsl:call-template>
		</xsl:if>
	</xsl:template>

	<!-- %%Template: GetFontCur
	-->
	<xsl:template name="GetFontCur">
		<xsl:param name="ndCur" />
		<xsl:param name="mathvariant" />
		<xsl:param name="fontstyle" />
		<xsl:param name="fontweight" />
		<xsl:choose>
			<xsl:when test="$mathvariant!=''">
				<xsl:value-of select="$mathvariant" />
			</xsl:when>
			<xsl:when test="not($ndCur)">
				<xsl:value-of select="'italic'" />
			</xsl:when>
			<xsl:when test="local-name($ndCur)='mi' and namespace-uri(.)='http://www.w3.org/1998/Math/MathML' and (string-length(normalize-space($ndCur))) &lt;= 1">

				<!--Default is fontweight = 'normal' and fontstyle='italic'
					In MathML if the string-length of the contents of an mi tag is =1, then the font
					of the contents is italics, however, if the length is >1, then the font is plain.
					This test considers the latter case.-->
				<xsl:choose>
					<xsl:when test="$fontstyle='normal' and $fontweight='bold'">
						<xsl:value-of select="'bold'" />
					</xsl:when>
					<xsl:when test="$fontstyle='normal'">
						<xsl:value-of select="'normal'" />
					</xsl:when>
					<xsl:when test="$fontstyle='bold'">
						<xsl:value-of select="'bi'" />
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="'italic'" />
					</xsl:otherwise>
				</xsl:choose>
			</xsl:when>
			<xsl:when test="local-name($ndCur)='mn' and namespace-uri(.)='http://www.w3.org/1998/Math/MathML' and string(number($ndCur/text()))!='NaN'">
				<xsl:value-of select="string(number($ndCur/text()))" />

				<!--Default is fontweight = 'normal' and fontstyle='italic'-->
				<xsl:choose>
					<xsl:when test="$fontstyle='normal' and $fontweight='bold'">
						<xsl:value-of select="'bold'" />
					</xsl:when>
					<xsl:when test="$fontstyle='normal'">
						<xsl:value-of select="'normal'" />
					</xsl:when>
					<xsl:when test="$fontstyle='bold'">
						<xsl:value-of select="'bi'" />
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="'italic'" />
					</xsl:otherwise>
				</xsl:choose>
			</xsl:when>
			<xsl:otherwise>

				<!--Default is fontweight = 'normal' and fontstyle='normal'-->
				<xsl:choose>
					<xsl:when test="$fontstyle='italic' and $fontweight='bold'">
						<xsl:value-of select="'bi'" />
					</xsl:when>
					<xsl:when test="$fontstyle='italic'">
						<xsl:value-of select="'italic'" />
					</xsl:when>
					<xsl:when test="$fontstyle='bold'">
						<xsl:value-of select="'bold'" />
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="'normal'" />
					</xsl:otherwise>
				</xsl:choose>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- %%Template: CreateMathScrStyProp
	-->
	<xsl:template name="CreateMathScrStyProp">
		<xsl:param name="font" />
		<xsl:element name="m:rPr">
			<xsl:choose>
				<xsl:when test="$font='normal'">
					<xsl:element name="m:sty">
						<xsl:attribute name="m:val">p</xsl:attribute>
					</xsl:element>
				</xsl:when>
				<xsl:when test="$font='bold'">
					<xsl:element name="m:sty">
						<xsl:attribute name="m:val">b</xsl:attribute>
					</xsl:element>
				</xsl:when>
				<xsl:when test="$font='italic'">
				</xsl:when>
				<xsl:when test="$font='script'">
					<xsl:element name="m:scr">
						<xsl:attribute name="m:val">script</xsl:attribute>
					</xsl:element>
				</xsl:when>
				<xsl:when test="$font='bold-script'">
					<xsl:element name="m:scr">
						<xsl:attribute name="m:val">script</xsl:attribute>
					</xsl:element>
					<xsl:element name="m:sty">
						<xsl:attribute name="m:val">b</xsl:attribute>
					</xsl:element>
				</xsl:when>
				<xsl:when test="$font='double-struck'">
					<xsl:element name="m:scr">
						<xsl:attribute name="m:val">double-struck</xsl:attribute>
					</xsl:element>
					<xsl:element name="m:sty">
						<xsl:attribute name="m:val">p</xsl:attribute>
					</xsl:element>
				</xsl:when>
				<xsl:when test="$font='fraktur'">
					<xsl:element name="m:scr">
						<xsl:attribute name="m:val">fraktur</xsl:attribute>
					</xsl:element>
					<xsl:element name="m:sty">
						<xsl:attribute name="m:val">p</xsl:attribute>
					</xsl:element>
				</xsl:when>
				<xsl:when test="$font='bold-fraktur'">
					<xsl:element name="m:scr">
						<xsl:attribute name="m:val">fraktur</xsl:attribute>
					</xsl:element>
					<xsl:element name="m:sty">
						<xsl:attribute name="m:val">b</xsl:attribute>
					</xsl:element>
				</xsl:when>
				<xsl:when test="$font='sans-serif'">
					<xsl:element name="m:scr">
						<xsl:attribute name="m:val">sans-serif</xsl:attribute>
					</xsl:element>
					<xsl:element name="m:sty">
						<xsl:attribute name="m:val">p</xsl:attribute>
					</xsl:element>
				</xsl:when>
				<xsl:when test="$font='bold-sans-serif'">
					<xsl:element name="m:scr">
						<xsl:attribute name="m:val">sans-serif</xsl:attribute>
					</xsl:element>
					<xsl:element name="m:sty">
						<xsl:attribute name="m:val">b</xsl:attribute>
					</xsl:element>
				</xsl:when>
				<xsl:when test="$font='sans-serif-italic'">
					<xsl:element name="m:scr">
						<xsl:attribute name="m:val">sans-serif</xsl:attribute>
					</xsl:element>
				</xsl:when>
				<xsl:when test="$font='monospace'" />	<!-- We can't do monospace, so leave empty -->
				<xsl:when test="$font='bold'">
					<xsl:element name="m:sty">
						<xsl:attribute name="m:val">b</xsl:attribute>
					</xsl:element>
				</xsl:when>
				<xsl:when test="$font='bi'">
					<xsl:element name="m:sty">
						<xsl:attribute name="m:val">bi</xsl:attribute>
					</xsl:element>
				</xsl:when>
			</xsl:choose>
		</xsl:element>
	</xsl:template>

	<xsl:template name="ZeroOrEmpty">
		<xsl:param name="sz" />
		<xsl:variable name="cchSz" select="string-length($sz)" />
		<xsl:variable name="szUnit" select="substring($sz,$cchSz - 1,2)" />
		<xsl:choose>
			<xsl:when test="$szUnit='em' or $szUnit='pt' or $szUnit='ex' or $szUnit='in' or $szUnit='cm' or $szUnit='mm' or $szUnit='pc'">
				<xsl:if test="number(substring($sz,1,$cchSz - 2)) = 0">0</xsl:if>
			</xsl:when>
			<xsl:when test="substring($sz,string-length($sz),1)='%' and string(number(substring($sz,1,$sz - 1)))!='NaN'">
				<xsl:if test="number(substring($sz,1,$cchSz - 1)) = 0">0</xsl:if>
			</xsl:when>
			<xsl:otherwise>
				<xsl:if test="number($sz) = $sz and number($sz) = 0">0</xsl:if>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- %%Template: match mfrac
	-->
	<xsl:template match="mml:mfrac">
		<xsl:variable name="nlinethickness">
			<xsl:call-template name="ZeroOrEmpty">
				<xsl:with-param name="sz" select="@linethickness" />
			</xsl:call-template>
		</xsl:variable>
		<xsl:element name="m:f">
			<xsl:element name="m:fPr">
				<xsl:element name="m:type">
					<xsl:attribute name="m:val">
						<xsl:choose>
							<xsl:when test="$nlinethickness = '0'">noBar</xsl:when>
							<xsl:when test="@bevelled='true'">skw</xsl:when>
							<xsl:otherwise>bar</xsl:otherwise>
						</xsl:choose>
					</xsl:attribute>
				</xsl:element>
			</xsl:element>
			<xsl:element name="m:num">
				<xsl:call-template name="CreateArgProp" />
				<xsl:apply-templates select="child::*[1]" />
			</xsl:element>
			<xsl:element name="m:den">
				<xsl:call-template name="CreateArgProp" />
				<xsl:apply-templates select="child::*[2]" />
			</xsl:element>
		</xsl:element>
	</xsl:template>

	<!-- %%Template: match menclose msqrt
	-->
	<xsl:template match="mml:menclose | mml:msqrt">
		<xsl:choose>
			<xsl:when test="@notation='radical' or not(@notation) or @notation='' or self::mml:msqrt">
				<xsl:element name="m:rad">
					<xsl:element name="m:radPr">
						<xsl:element name="m:degHide">
							<xsl:attribute name="m:val">on</xsl:attribute>
						</xsl:element>
					</xsl:element>
					<xsl:element name="m:deg">
						<xsl:call-template name="CreateArgProp" />
					</xsl:element>
					<xsl:element name="m:e">
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="*" />
					</xsl:element>
				</xsl:element>
			</xsl:when>
		</xsl:choose>
	</xsl:template>

	<!-- %%Template: CreateArgProp
	-->
	<xsl:template name="CreateArgProp">
		<xsl:if test="not(count(ancestor-or-self::mml:mstyle[@scriptlevel='0' or @scriptlevel='1' or @scriptlevel='2'])=0)">
			<xsl:element name="m:argPr">
				<xsl:element name="m:scrLvl">
					<xsl:attribute name="m:val">
						<xsl:value-of select="ancestor-or-self::mml:mstyle[@scriptlevel][1]/@scriptlevel" />
					</xsl:attribute>
				</xsl:element>
			</xsl:element>
		</xsl:if>
	</xsl:template>

	<!-- %%Template: match mroot
	-->
	<xsl:template match="mml:mroot">
		<xsl:element name="m:rad">
			<xsl:element name="m:radPr">
				<xsl:element name="m:degHide">
					<xsl:attribute name="m:val">off</xsl:attribute>
				</xsl:element>
			</xsl:element>
			<xsl:element name="m:deg">
				<xsl:call-template name="CreateArgProp" />
				<xsl:apply-templates select="child::*[2]" />
			</xsl:element>
			<xsl:element name="m:e">
				<xsl:call-template name="CreateArgProp" />
				<xsl:apply-templates select="child::*[1]" />
			</xsl:element>
		</xsl:element>
	</xsl:template>

	<!-- %%Template: match munder
	-->
	<xsl:template match="mml:munder">
		<xsl:variable name="fNary">
			<xsl:call-template name="isNary">
				<xsl:with-param name="ndCur" select="child::*[1]" />
			</xsl:call-template>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="$fNary='true'">
				<m:nary>
					<xsl:call-template name="CreateNaryProp">
						<xsl:with-param name="chr">
							<xsl:value-of select="normalize-space(child::*[1])" />
						</xsl:with-param>
						<xsl:with-param name="sMathmlType" select="'munder'" />
					</xsl:call-template>
					<m:sub>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[2]" />
					</m:sub>
					<m:sup>
						<xsl:call-template name="CreateArgProp" />
					</m:sup>
					<m:e>
						<xsl:call-template name="CreateArgProp" />

						<!-- if the next sibling is an mrow, pull it in by
							doing whatever we would have done to its children.
							The mrow itself will be skipped, see template above. -->
						<xsl:if test="following-sibling::*[1][self::mml:mrow|self::mml:mstyle]">
							<xsl:apply-templates select="following-sibling::*[1]/*" />
						</xsl:if>
					</m:e>
				</m:nary>
			</xsl:when>
			<xsl:otherwise>
				<xsl:element name="m:limLow">
					<xsl:element name="m:e">
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[1]" />
					</xsl:element>
					<xsl:element name="m:lim">
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[2]" />
					</xsl:element>
				</xsl:element>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- %%Template: match mover
	-->
	<xsl:template match="mml:mover">
		<xsl:variable name="fNary">
			<xsl:call-template name="isNary">
				<xsl:with-param name="ndCur" select="child::*[1]" />
			</xsl:call-template>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="$fNary='true'">
				<m:nary>
					<xsl:call-template name="CreateNaryProp">
						<xsl:with-param name="chr">
							<xsl:value-of select="normalize-space(child::*[1])" />
						</xsl:with-param>
						<xsl:with-param name="sMathmlType" select="'mover'" />
					</xsl:call-template>
					<m:sub>
						<xsl:call-template name="CreateArgProp" />
					</m:sub>
					<m:sup>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[2]" />
					</m:sup>
					<m:e>
						<xsl:call-template name="CreateArgProp" />

						<!-- if the next sibling is an mrow, pull it in by
							 doing whatever we would have done to its children.
							The mrow itself will be skipped, see template above. -->
						<xsl:if test="following-sibling::*[1][self::mml:mrow|self::mml:mstyle]">
							<xsl:apply-templates select="following-sibling::*[1]/*" />
						</xsl:if>
					</m:e>
				</m:nary>
			</xsl:when>
			<xsl:otherwise>
				<xsl:element name="m:limUpp">
					<xsl:element name="m:e">
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[1]" />
					</xsl:element>
					<xsl:element name="m:lim">
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[2]" />
					</xsl:element>
				</xsl:element>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- %%Template: match munderover
	-->
	<xsl:template match="mml:munderover">
		<xsl:variable name="fNary">
			<xsl:call-template name="isNary">
				<xsl:with-param name="ndCur" select="child::*[1]" />
			</xsl:call-template>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="$fNary='true'">
				<m:nary>
					<xsl:call-template name="CreateNaryProp">
						<xsl:with-param name="chr">
							<xsl:value-of select="normalize-space(child::*[1])" />
						</xsl:with-param>
						<xsl:with-param name="sMathmlType" select="'munderover'" />
					</xsl:call-template>
					<m:sub>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[2]" />
					</m:sub>
					<m:sup>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[3]" />
					</m:sup>
					<m:e>
						<xsl:call-template name="CreateArgProp" />

						<!-- if the next sibling is an mrow, pull it in by
							 doing whatever we would have done to its children.
							The mrow itself will be skipped, see template above. -->
						<xsl:if test="following-sibling::*[1][self::mml:mrow|self::mml:mstyle]">
							<xsl:apply-templates select="following-sibling::*[1]/*" />
						</xsl:if>
					</m:e>
				</m:nary>
			</xsl:when>
			<xsl:otherwise>
				<xsl:element name="m:limUpp">
					<xsl:element name="m:e">
						<xsl:call-template name="CreateArgProp" />
						<xsl:element name="m:limLow">
							<xsl:element name="m:e">
								<xsl:call-template name="CreateArgProp" />
								<xsl:apply-templates select="child::*[1]" />
							</xsl:element>
							<xsl:element name="m:lim">
								<xsl:call-template name="CreateArgProp" />
								<xsl:apply-templates select="child::*[2]" />
							</xsl:element>
						</xsl:element>
					</xsl:element>
					<xsl:element name="m:lim">
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[3]" />
					</xsl:element>
				</xsl:element>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- %%Template: match mfenced -->
	<xsl:template match="mml:mfenced">
		<m:d>
			<xsl:call-template name="CreateDelimProp">
				<xsl:with-param name="chOpen" select="@open" />
				<xsl:with-param name="chSeperators" select="@separators" />
				<xsl:with-param name="chClose" select="@close" />
			</xsl:call-template>
			<xsl:for-each select="*">
				<m:e>
					<xsl:call-template name="CreateArgProp" />
					<xsl:apply-templates select="."/>
				</m:e>
			</xsl:for-each>
		</m:d>
	</xsl:template>

	<!-- %%Template: CreateDelimProp

		Given the characters to use as open, close and separators for
		the delim object, create the m:dPr (delim properties).

		MathML can have any number of separators in an mfenced object, but
		OMML can only represent one separator for each d (delim) object.
		So, we pick the first separator specified.
	-->
	<xsl:template name="CreateDelimProp">
		<xsl:param name="chOpen" />
		<xsl:param name="chSeperators" />
		<xsl:param name="chClose" />

		<xsl:variable name="chSep" select="substring($chSeperators, 1, 1)" />

		<!-- do we need a dPr at all? If everything's at its default value, then
			don't bother at all -->
		<xsl:if test="($chOpen and not($chOpen = '(')) or
						  ($chClose and not($chClose = ')')) or
						  not($chSep = '|')">
			<m:dPr>
				<!-- the default for MathML and OMML is '('. -->
				<xsl:if test="$chOpen and not($chOpen = '(')">
					<m:begChr>
						<xsl:attribute name="m:val">
							<xsl:value-of select="$chOpen" />
						</xsl:attribute>
					</m:begChr>
				</xsl:if>

				<!-- the default for MathML is ',' and for OMML is '|' -->

				<xsl:choose>
					<!-- matches OMML's default, don't bother to write anything out -->
					<xsl:when test="$chSep = '|'" />

					<!-- Not specified, use MathML's default. We test against
					the existence of the actual attribute, not the substring -->
					<xsl:when test="not($chSeperators)">
						<m:sepChr m:val=',' />
					</xsl:when>

					<xsl:otherwise>
						<m:sepChr>
							<xsl:attribute name="m:val">
								<xsl:value-of select="$chSep" />
							</xsl:attribute>
						</m:sepChr>
					</xsl:otherwise>
				</xsl:choose>

				<!-- the default for MathML and OMML is ')'. -->
				<xsl:if test="$chClose and not($chClose = ')')">
					<m:endChr>
						<xsl:attribute name="m:val">
							<xsl:value-of select="$chClose" />
						</xsl:attribute>
					</m:endChr>
				</xsl:if>
			</m:dPr>
		</xsl:if>
	</xsl:template>

	<!-- %%Template: OutputMs
	-->
	<xsl:template name="OutputMs">
		<xsl:param name="msCur" />
		<xsl:choose>
			<xsl:when test="not($msCur/@lquote) or $msCur/@lquote=''">
				<xsl:text>"</xsl:text>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$msCur/@lquote" />
			</xsl:otherwise>
		</xsl:choose>
		<xsl:value-of select="normalize-space($msCur)" />
		<xsl:choose>
			<xsl:when test="not($msCur/@rquote) or $msCur/@rquote=''">
				<xsl:text>"</xsl:text>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$msCur/@rquote" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- %%Template: match msub
	-->
	<xsl:template match="mml:msub">
		<xsl:variable name="fNary">
			<xsl:call-template name="isNary">
				<xsl:with-param name="ndCur" select="child::*[1]" />
			</xsl:call-template>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="$fNary='true'">
				<m:nary>
					<xsl:call-template name="CreateNaryProp">
						<xsl:with-param name="chr">
							<xsl:value-of select="normalize-space(child::*[1])" />
						</xsl:with-param>
						<xsl:with-param name="sMathmlType" select="'msub'" />
					</xsl:call-template>
					<m:sub>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[2]" />
					</m:sub>
					<m:sup>
						<xsl:call-template name="CreateArgProp" />
					</m:sup>
					<m:e>
						<xsl:call-template name="CreateArgProp" />

						<!--if the next sibling is an mrow, pull it in by
							doing whatever we would have done to its children.
							The mrow itself will be skipped, see template above. -->
						<xsl:if test="following-sibling::*[1][self::mml:mrow|self::mml:mstyle]">
							<xsl:apply-templates select="following-sibling::*[1]/*" />
						</xsl:if>
					</m:e>
				</m:nary>
			</xsl:when>
			<xsl:otherwise>
				<m:sSub>
					<m:e>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[1]" />
					</m:e>
					<m:sub>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[2]" />
					</m:sub>
				</m:sSub>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- %%Template: match msup
	-->
	<xsl:template match="mml:msup">
		<xsl:variable name="fNary">
			<xsl:call-template name="isNary">
				<xsl:with-param name="ndCur" select="child::*[1]" />
			</xsl:call-template>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="$fNary='true'">
				<m:nary>
					<xsl:call-template name="CreateNaryProp">
						<xsl:with-param name="chr">
							<xsl:value-of select="normalize-space(child::*[1])" />
						</xsl:with-param>
						<xsl:with-param name="sMathmlType" select="'msup'" />
					</xsl:call-template>
					<m:sub>
						<xsl:call-template name="CreateArgProp" />
					</m:sub>
					<m:sup>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[2]" />
					</m:sup>
					<m:e>
						<xsl:call-template name="CreateArgProp" />

						<!--if the next sibling is an mrow, pull it in by
							doing whatever we would have done to its children.
							The mrow itself will be skipped, see template above. -->
						<xsl:if test="following-sibling::*[1][self::mml:mrow|self::mml:mstyle]">
							<xsl:apply-templates select="following-sibling::*[1]/*" />
						</xsl:if>
					</m:e>
				</m:nary>
			</xsl:when>
			<xsl:otherwise>
				<m:sSup>
					<m:e>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[1]" />
					</m:e>
					<m:sup>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[2]" />
					</m:sup>
				</m:sSup>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- %%Template: match msubsup
	-->
	<xsl:template match="mml:msubsup">
		<xsl:variable name="fNary">
			<xsl:call-template name="isNary">
				<xsl:with-param name="ndCur" select="child::*[1]" />
			</xsl:call-template>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="$fNary='true'">
				<m:nary>
					<xsl:call-template name="CreateNaryProp">
						<xsl:with-param name="chr">
							<xsl:value-of select="normalize-space(child::*[1])" />
						</xsl:with-param>
						<xsl:with-param name="sMathmlType" select="'msubsup'" />
					</xsl:call-template>
					<m:sub>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[2]" />
					</m:sub>
					<m:sup>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[3]" />
					</m:sup>
					<m:e>
						<xsl:call-template name="CreateArgProp" />

						<!--if the next sibling is an mrow, pull it in by
							doing whatever we would have done to its children.
							The mrow itself will be skipped, see template above. -->
						<xsl:if test="following-sibling::*[1][self::mml:mrow|self::mml:mstyle]">
							<xsl:apply-templates select="following-sibling::*[1]/*" />
						</xsl:if>
					</m:e>
				</m:nary>
			</xsl:when>
			<xsl:otherwise>
				<m:sSubSup>
					<m:e>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[1]" />
					</m:e>
					<m:sub>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[2]" />
					</m:sub>
					<m:sup>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[3]" />
					</m:sup>
				</m:sSubSup>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- %%Template: SplitScripts

		Takes an collection of nodes, and splits them
		odd and even into sup and sub scripts. Used for dealing with
		mmultiscript.
		-->
	<xsl:template name="SplitScripts">
		<xsl:param name="ndScripts" />

		<m:sub>
			<xsl:call-template name="CreateArgProp" />
			<xsl:apply-templates select="$ndScripts[(position() mod 2) = 1]" />
		</m:sub>

		<m:sup>
			<xsl:call-template name="CreateArgProp" />
			<xsl:apply-templates select="$ndScripts[(position() mod 2) = 0]" />
		</m:sup>
	</xsl:template>

	<!-- %%Template: match mmultiscripts

		There is some subtlety with the mml:mprescripts element. Everything that comes before
		that is considered a script (as opposed to a pre-script), but it need not be present.
	-->
	<xsl:template match="mml:mmultiscripts">

		<!-- count the nodes. Everything that comes after a mml:mprescripts is considered a pre-script;
			Everything that does not have an mml:mprescript as a preceding-sibling (and is not itself
			mml:mprescript) is a script, except for the first child which is always the base -->
		<xsl:variable name="nndPrescript" select="count(mml:mprescripts[1]/following-sibling::*)" />
		<xsl:variable name="nndScript" select="count(*[not(preceding-sibling::mml:mprescripts) and not(self::mml:mprescripts)]) - 1" />

		<xsl:choose>

			<!-- The easy case first. No prescripts, and no script ... just a base -->
			<xsl:when test="$nndPrescript &lt;= 0 and $nndScript &lt;= 0">
				<xsl:apply-templates select="*[1]" />
			</xsl:when>

			<!-- Next, if there are no prescripts -->
			<xsl:when test="$nndPrescript &lt;= 0">
				<!-- we know we have some scripts or else we would have taken the earlier
					  branch. So, create a subsup and split the elements -->
				<m:sSubSup>
					<m:e>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[1]" />
					</m:e>

					<!-- Every child except the first is a script, split -->
					<xsl:call-template name="SplitScripts">
						<xsl:with-param name="ndScripts" select="*[position() &gt; 1]" />
					</xsl:call-template>
				</m:sSubSup>
			</xsl:when>

			<!-- Next, if there are no scripts -->
			<xsl:when test="$nndScript &lt;= 0">
				<!-- we know we have some prescripts or else we would have taken the earlier
					  branch. So, create a sPre and split the elements -->
				<m:sPre>
					<m:e>
						<xsl:call-template name="CreateArgProp" />
						<xsl:apply-templates select="child::*[1]" />
					</m:e>

					<!-- The prescripts come after the mml:mprescript and if we get here
							we know there exists one such element -->
					<xsl:call-template name="SplitScripts">
						<xsl:with-param name="ndScripts" select="mml:mprescripts[1]/following-sibling::*" />
					</xsl:call-template>
				</m:sPre>
			</xsl:when>

			<!-- Finally, the case with both prescripts and scripts. Create a sPre
				element to house the prescripts, with a subsup element at its base. -->
			<xsl:otherwise>
				<m:sPre>
					<m:e>
						<m:sSubSup>
							<m:e>
								<xsl:call-template name="CreateArgProp" />
								<xsl:apply-templates select="child::*[1]" />
							</m:e>

							<!-- scripts come before the mml:mprescript but after the first child, so their
								 positions will be 2, 3, ... ($nndScript + 1) -->
							<xsl:call-template name="SplitScripts">
								<xsl:with-param name="ndScripts" select="*[(position() &gt; 1) and (position() &lt;= ($nndScript + 1))]" />
							</xsl:call-template>
						</m:sSubSup>
					</m:e>

					<!-- The prescripts come after the mml:mprescript and if we get here
							we know there exists one such element -->
					<xsl:call-template name="SplitScripts">
						<xsl:with-param name="ndScripts" select="mml:mprescripts[1]/following-sibling::*" />
					</xsl:call-template>
				</m:sPre>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>


	<xsl:template match="mml:mtable">
		<xsl:variable name="cMaxElmtsInRow">
			<xsl:call-template name="CountMaxElmtsInRow">
				<xsl:with-param name="ndCur" select="*[1]" />
				<xsl:with-param name="cMaxElmtsInRow" select="0" />
			</xsl:call-template>
		</xsl:variable>
		<m:m>
			<m:mPr>
				<m:baseJc m:val="center" />
				<m:plcHide m:val="on" />
				<m:mcs>
					<m:mc>
						<m:mcPr>
							<m:count>
								<xsl:attribute name="m:val">
									<xsl:value-of select="$cMaxElmtsInRow" />
								</xsl:attribute>
							</m:count>
							<m:mcJc m:val="center" />
						</m:mcPr>
					</m:mc>
				</m:mcs>
			</m:mPr>
			<xsl:for-each select="*">
				<xsl:choose>
					<xsl:when test="self::mml:mtr or self::mml:mlabeledtr">
						<m:mr>
							<xsl:choose>
								<xsl:when test="self::mml:mtr">
									<xsl:for-each select="*">
										<m:e>
											<xsl:apply-templates select="." />
										</m:e>
									</xsl:for-each>
									<xsl:call-template name="CreateEmptyElmt">
										<xsl:with-param name="cEmptyMtd" select="$cMaxElmtsInRow - count(*)" />
									</xsl:call-template>
								</xsl:when>
								<xsl:otherwise>
									<xsl:for-each select="*[position() &gt; 1]">
										<m:e>
											<xsl:apply-templates select="." />
										</m:e>
									</xsl:for-each>
									<xsl:call-template name="CreateEmptyElmt">
										<xsl:with-param name="cEmptyMtd" select="$cMaxElmtsInRow - (count(*) - 1)" />
									</xsl:call-template>
								</xsl:otherwise>
							</xsl:choose>
						</m:mr>
					</xsl:when>
					<xsl:otherwise>
						<m:mr>
							<m:e>
								<xsl:apply-templates select="." />
							</m:e>
							<xsl:call-template name="CreateEmptyElmt">
								<xsl:with-param name="cEmptyMtd" select="$cMaxElmtsInRow - 1" />
							</xsl:call-template>
						</m:mr>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:for-each>
		</m:m>
	</xsl:template>
	<xsl:template match="m:mtd">
		<xsl:apply-templates select="*" />
	</xsl:template>
	<xsl:template name="CreateEmptyElmt">
		<xsl:param name="cEmptyMtd" />
		<xsl:if test="$cEmptyMtd &gt; 0">
			<m:e></m:e>
			<xsl:call-template name="CreateEmptyElmt">
				<xsl:with-param name="cEmptyMtd" select="$cEmptyMtd - 1" />
			</xsl:call-template>
		</xsl:if>
	</xsl:template>
	<xsl:template name="CountMaxElmtsInRow">
		<xsl:param name="ndCur" />
		<xsl:param name="cMaxElmtsInRow" select="0" />
		<xsl:choose>
			<xsl:when test="not($ndCur)">
				<xsl:value-of select="$cMaxElmtsInRow" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:call-template name="CountMaxElmtsInRow">
					<xsl:with-param name="ndCur" select="$ndCur/following-sibling::*[1]" />
					<xsl:with-param name="cMaxElmtsInRow">
						<xsl:choose>
							<xsl:when test="local-name($ndCur) = 'mlabeledtr' and
								            namespace-uri($ndCur) = 'http://www.w3.org/1998/Math/MathML'">
								<xsl:choose>
									<xsl:when test="(count($ndCur/*) - 1) &gt; $cMaxElmtsInRow">
										<xsl:value-of select="count($ndCur/*) - 1" />
									</xsl:when>
									<xsl:otherwise>
										<xsl:value-of select="$cMaxElmtsInRow" />
									</xsl:otherwise>
								</xsl:choose>
							</xsl:when>
							<xsl:when test="local-name($ndCur) = 'mtr' and
								            namespace-uri($ndCur) = 'http://www.w3.org/1998/Math/MathML'">
								<xsl:choose>
									<xsl:when test="count($ndCur/*) &gt; $cMaxElmtsInRow">
										<xsl:value-of select="count($ndCur/*)" />
									</xsl:when>
									<xsl:otherwise>
										<xsl:value-of select="$cMaxElmtsInRow" />
									</xsl:otherwise>
								</xsl:choose>
							</xsl:when>
							<xsl:otherwise>
								<xsl:choose>
									<xsl:when test="1 &gt; $cMaxElmtsInRow">
										<xsl:value-of select="1" />
									</xsl:when>
									<xsl:otherwise>
										<xsl:value-of select="$cMaxElmtsInRow" />
									</xsl:otherwise>
								</xsl:choose>
							</xsl:otherwise>
						</xsl:choose>
					</xsl:with-param>
				</xsl:call-template>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template match="mml:mglyph">
		<xsl:call-template name="CreateMglyph" />
	</xsl:template>
	<xsl:template match="mml:mi[child::mml:mglyph] |
	                     mml:mn[child::mml:mglyph] |
	                     mml:mo[child::mml:mglyph] |
	                     mml:ms[child::mml:mglyph] |
	                     mml:mtext[child::mml:mglyph]">
		<xsl:element name="m:r">
			<xsl:call-template name="CreateRunProp">
				<xsl:with-param name="mathvariant" select="@mathvariant" />
				<xsl:with-param name="fontstyle" select="@fontstyle" />
				<xsl:with-param name="fontweight" select="@fontweight" />
				<xsl:with-param name="mathcolor" select="@mathcolor" />
				<xsl:with-param name="mathsize" select="@mathsize" />
				<xsl:with-param name="color" select="@color" />
				<xsl:with-param name="fontsize" select="@fontsize" />
				<xsl:with-param name="ndCur" select="." />
			</xsl:call-template>
			<xsl:element name="m:t">
				<xsl:call-template name="OutputText">
					<xsl:with-param name="sInput">
						<xsl:choose>
							<xsl:when test="self::mml:ms">
								<xsl:call-template name="OutputMs">
									<xsl:with-param name="msCur" select="." />
								</xsl:call-template>
							</xsl:when>
							<xsl:otherwise>
								<xsl:value-of select="normalize-space(.)" />
							</xsl:otherwise>
						</xsl:choose>
					</xsl:with-param>
				</xsl:call-template>
			</xsl:element>
		</xsl:element>
		<xsl:for-each select="child::mml:mglyph">
			<xsl:call-template name="CreateMglyph">
				<xsl:with-param name="ndCur" select="." />
			</xsl:call-template>
		</xsl:for-each>
	</xsl:template>
	<xsl:template name="FGlyphIndexOk">
		<xsl:param name="index" />
		<xsl:if test="$index != ''">
			<xsl:choose>
				<xsl:when test="string(number(string(floor($index)))) = 'NaN'" />
				<xsl:when test="number($index) &lt; 32 and not(number($index) = 9 or number($index) = 10 or number($index) = 13)" />
				<xsl:when test="number($index) = 65534 or number($index) = 65535" />
				<xsl:otherwise>1</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
	</xsl:template>
	<xsl:template name="CreateMglyph">
		<xsl:param name="ndCur" />
		<m:r>
			<xsl:call-template name="CreateRunProp">
				<xsl:with-param name="mathvariant">
					<xsl:choose>
						<xsl:when test="(not(@mathvariant) or @mathvariant='') and ../@mathvariant!=''">
							<xsl:value-of select="../@mathvariant" />
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="@mathvariant" />
						</xsl:otherwise>
					</xsl:choose>
				</xsl:with-param>
				<xsl:with-param name="fontstyle">
					<xsl:choose>
						<xsl:when test="(not(@fontstyle) or @fontstyle='') and ../@fontstyle!=''">
							<xsl:value-of select="../@fontstyle" />
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="@fontstyle" />
						</xsl:otherwise>
					</xsl:choose>
				</xsl:with-param>
				<xsl:with-param name="fontweight">
					<xsl:choose>
						<xsl:when test="(not(@fontweight) or @fontweight='') and ../@fontweight!=''">
							<xsl:value-of select="../@fontweight" />
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="@fontweight" />
						</xsl:otherwise>
					</xsl:choose>
				</xsl:with-param>
				<xsl:with-param name="mathcolor">
					<xsl:choose>
						<xsl:when test="(not(@mathcolor) or @mathcolor='') and ../@mathcolor!=''">
							<xsl:value-of select="../@mathcolor" />
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="@mathcolor" />
						</xsl:otherwise>
					</xsl:choose>
				</xsl:with-param>
				<xsl:with-param name="mathsize">
					<xsl:choose>
						<xsl:when test="(not(@mathsize) or @mathsize='') and ../@mathsize!=''">
							<xsl:value-of select="../@mathsize" />
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="@mathsize" />
						</xsl:otherwise>
					</xsl:choose>
				</xsl:with-param>
				<xsl:with-param name="color">
					<xsl:choose>
						<xsl:when test="(not(@color) or @color='') and ../@color!=''">
							<xsl:value-of select="../@color" />
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="@color" />
						</xsl:otherwise>
					</xsl:choose>
				</xsl:with-param>
				<xsl:with-param name="fontsize">
					<xsl:choose>
						<xsl:when test="(not(@fontsize) or @fontsize='') and ../@fontsize!=''">
							<xsl:value-of select="../@fontsize" />
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="@fontsize" />
						</xsl:otherwise>
					</xsl:choose>
				</xsl:with-param>
				<xsl:with-param name="ndCur" select="." />
				<xsl:with-param name="fontfamily" select="@fontfamily" />
			</xsl:call-template>
			<xsl:variable name="shouldGlyphUseIndex">
				<xsl:call-template name="FGlyphIndexOk">
					<xsl:with-param name="index" select="@index" />
				</xsl:call-template>
			</xsl:variable>
			<xsl:choose>
				<xsl:when test="not($shouldGlyphUseIndex = '1')">
					<m:t>
						<xsl:value-of select="@alt" />
					</m:t>
				</xsl:when>
				<xsl:otherwise>
					<xsl:variable name="nHexIndex">
						<xsl:call-template name="ConvertDecToHex">
							<xsl:with-param name="index" select="@index" />
						</xsl:call-template>
					</xsl:variable>
					<m:t>
						<xsl:text disable-output-escaping="yes">&amp;#x</xsl:text>
						<xsl:value-of select="$nHexIndex" />
						<xsl:text>;</xsl:text>
					</m:t>
				</xsl:otherwise>
			</xsl:choose>
		</m:r>
	</xsl:template>
	<xsl:template name="ConvertDecToHex">
		<xsl:param name="index" />
		<xsl:if test="$index > 0">
			<xsl:call-template name="ConvertDecToHex">
				<xsl:with-param name="index" select="floor($index div 16)" />
			</xsl:call-template>
			<xsl:choose>
				<xsl:when test="$index mod 16 &lt; 10">
					<xsl:value-of select="$index mod 16" />
				</xsl:when>
				<xsl:otherwise>
					<xsl:choose>
						<xsl:when test="$index mod 16 = 10">A</xsl:when>
						<xsl:when test="$index mod 16 = 11">B</xsl:when>
						<xsl:when test="$index mod 16 = 12">C</xsl:when>
						<xsl:when test="$index mod 16 = 13">D</xsl:when>
						<xsl:when test="$index mod 16 = 14">E</xsl:when>
						<xsl:when test="$index mod 16 = 15">F</xsl:when>
						<xsl:otherwise>A</xsl:otherwise>
					</xsl:choose>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
	</xsl:template>
	<xsl:template match="mml:mphantom">
		<m:phant>
			<m:phantPr>
				<m:width m:val="on" />
				<m:asc m:val="on" />
				<m:dec m:val="on" />
			</m:phantPr>
			<m:e>
				<xsl:apply-templates select="*" />
			</m:e>
		</m:phant>
	</xsl:template>
	<xsl:template name="isNaryOper">
		<xsl:param name="sNdCur" />
		<xsl:value-of select="($sNdCur = '&#x222B;' or $sNdCur = '&#x222C;' or $sNdCur = '&#x222D;' or $sNdCur = '&#x222E;' or $sNdCur = '&#x222F;' or $sNdCur = '&#x2230;' or $sNdCur = '&#x2232;' or $sNdCur = '&#x2233;' or $sNdCur = '&#x2231;' or $sNdCur = '&#x2229;' or $sNdCur = '&#x222A;' or $sNdCur = '&#x220F;' or $sNdCur = '&#x2210;' or $sNdCur = '&#x2211;')" />
	</xsl:template>
	<xsl:template name="isNary">
		<xsl:param name="ndCur" />
		<xsl:variable name="sNdCur">
			<xsl:value-of select="normalize-space($ndCur)" />
		</xsl:variable>
		<xsl:variable name="fNaryOper">
			<xsl:call-template name="isNaryOper">
				<xsl:with-param name="sNdCur" select="$sNdCur" />
			</xsl:call-template>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="local-name($ndCur/descendant-or-self::*[last()])    = 'mo'         and
			                not($ndCur/descendant-or-self::*[not(self::mml:mo or
			                                                     self::mml:mstyle or
			                                                     self::mml:mrow)])             and
			                namespace-uri($ndCur/descendant-or-self::*[last()]) = 'http://www.w3.org/1998/Math/MathML'   and
			                $fNaryOper = 'true'">
				<xsl:value-of select="true()" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="false()" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template name="CreateNaryProp">
		<xsl:param name="chr" />
		<xsl:param name="sMathmlType" />
		<m:naryPr>
			<m:chr>
				<xsl:attribute name="m:val">
					<xsl:value-of select="$chr" />
				</xsl:attribute>
			</m:chr>
			<m:limLoc>
				<xsl:attribute name="m:val">
					<xsl:choose>
						<xsl:when test="$sMathmlType='munder' or
									$sMathmlType='mover' or
									$sMathmlType='munderover'">
							<xsl:text>undOvr</xsl:text>
						</xsl:when>
						<xsl:when test="$sMathmlType='msub' or
					                $sMathmlType='msup' or
					                $sMathmlType='msubsup'">
							<xsl:text>subSup</xsl:text>
						</xsl:when>
					</xsl:choose>
				</xsl:attribute>
			</m:limLoc>
			<m:grow>
				<xsl:attribute name="m:val">
					<xsl:value-of select="'on'" />
				</xsl:attribute>
			</m:grow>
			<m:subHide>
				<xsl:attribute name="m:val">
					<xsl:choose>
						<xsl:when test="$sMathmlType='mover' or
						                $sMathmlType='msup'">
							<xsl:text>on</xsl:text>
						</xsl:when>
						<xsl:otherwise>
							<xsl:text>off</xsl:text>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:attribute>
			</m:subHide>
			<m:supHide>
				<xsl:attribute name="m:val">
					<xsl:choose>
						<xsl:when test="$sMathmlType='munder' or
						                $sMathmlType='msub'">
							<xsl:text>on</xsl:text>
						</xsl:when>
						<xsl:otherwise>
							<xsl:text>off</xsl:text>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:attribute>
			</m:supHide>
		</m:naryPr>
	</xsl:template>
</xsl:stylesheet>
