<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xsl:stylesheet [ <!ENTITY nbsp "&#160;"> ]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
  <xsl:output 
    method="xml" indent="no" encoding="UTF-8" 
    doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"
    doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"/>

  <!-- strip spaces from all elements -->
  <xsl:strip-space elements="*" />

  <!-- preserve the whitsepace in token elements though -->
  <xsl:preserve-space elements="token" />

  <!-- default catch all template -->
  <xsl:template match="*" />
 
  <!-- the main HTML wrapping -->
  <xsl:template match="/parser_output">
    <html>
    <head>
      <title>SAF Parser Output</title>
      <link rel="stylesheet" type="text/css" href="parser.css" />
    </head>
    <body>
      <h1>SAF Parser Output</h1>
      <xsl:apply-templates select="programs" />
      <xsl:apply-templates select="tokens" />
      <xsl:apply-templates select="errors" />
    </body>
    </html>
  </xsl:template>
 
  <!-- the token list -->
  <xsl:template match="tokens">
    <div id="tokens_section">
      <h2 class="section_header">Tokens</h2>
      <code id="tokens">
         <xsl:apply-templates />
      </code>
    </div>
  </xsl:template>

  <!-- a token -->
  <xsl:template match="token">
    <span class="token">
      <xsl:attribute name="id">token_<xsl:value-of select="position()-1" /></xsl:attribute>
      <xsl:attribute name="class">token <xsl:value-of select="@type" /></xsl:attribute>
      <xsl:choose>
        <xsl:when test="@type='line_break'">
          <br />
        </xsl:when>
        <xsl:when test="@type='whitespace'">
          <!-- FIXME: this converts *all* whitespace characters to a non-break-space. -->
          <xsl:value-of select="translate(., '&#x20;&#x9;&#xD;&#xA;', '&nbsp;')" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="." />
        </xsl:otherwise>
      </xsl:choose>
    </span>
  </xsl:template>
 
  <!-- the error list -->
  <xsl:template match="errors">
    <div id="errors_section">
      <h2 class="section_header">Errors</h2>
      <ul class="errors">
         <xsl:apply-templates />
      </ul>
    </div>
  </xsl:template>

  <xsl:template match="error">
    <li class="error">
      <xsl:call-template name="error-node" />
    </li>
  </xsl:template>

  <xsl:template match="warning">
    <li class="warning">
      <xsl:call-template name="error-node" />
    </li>
  </xsl:template>

  <xsl:template name="error-node">
    <xsl:variable name="label" select="name()" />
    <xsl:variable name="first"><xsl:value-of select="@first" /></xsl:variable>
    <xsl:variable name="last"><xsl:value-of select="@last" /></xsl:variable>
    <xsl:variable name="first_token" 
      select="/descendant::token[position()=number($first)+1]" />
    <xsl:variable name="last_token" 
      select="/descendant::token[position()=number($last)+1]" />
    <xsl:variable name="start"
      select="$first_token/bounds/location[position()=1]" />
    <xsl:variable name="end"
      select="$last_token/bounds/location[position()=2]" />
    <span class="input_name"><xsl:value-of select="@input-name"
    /></span>:<span class="start line"><xsl:value-of select="$start/@line" 
      /></span>.<span class="start column"><xsl:value-of select="$start/@column" 
      /></span>-<span class="end line"><xsl:value-of select="$end/@line"
      /></span>.<span class="end column"><xsl:value-of select="$end/@column" 
      /></span>: <span class="label"><xsl:value-of select="$label"
      /></span>: <span class="message"><xsl:value-of select="." /></span>
    </xsl:template>

  <!-- the programs -->
  <xsl:template match="programs">
    <div id="programs_section">
      <h2 class="section_header">Programs</h2>
      <div id="programs">
        <ul>
          <xsl:for-each select="node">
            <li><xsl:apply-templates select="."/></li>
          </xsl:for-each>
        </ul>
      </div>
    </div>
  </xsl:template>

  <!-- an AST node -->
  <xsl:template match="node">
    <div>
      <xsl:attribute name="class">ast_node <xsl:value-of select="@type" /></xsl:attribute>
      <h3 class="type">
        <xsl:value-of select="@type" /><xsl:if test="@name != ''">:
        <xsl:value-of select="@name" />
        </xsl:if>
      </h3>
      <div class="description">
        <h3 class="label">Description</h3>
        <xsl:choose>
          <xsl:when test="@type='program'">
            <xsl:call-template name="program_node" />
          </xsl:when>
          <xsl:when test="@type='gobbet'">
            <xsl:call-template name="gobbet_node" />
          </xsl:when>
          <xsl:when test="@type='variabledeclaration'">
            <xsl:call-template name="variabledeclaration_node" />
          </xsl:when>
          <xsl:otherwise>
            AST node of type: <xsl:value-of select="@type" />
          </xsl:otherwise>
        </xsl:choose>
        <xsl:for-each select="children">
          <xsl:call-template name="children" />
        </xsl:for-each>
      </div>
      <div class="location">
        <h3 class="label">Location</h3>
        <ul>
          <li>
            <span class="label">First token index: </span>
            <span class="first"><xsl:value-of select="tokens/@first" /></span>
          </li>
          <li>
            <span class="label">Last token index: </span>
            <span class="last"><xsl:value-of select="tokens/@last" /></span>
          </li>
        </ul>
      </div>
    </div>
  </xsl:template>

  <!-- A node's children -->
  <xsl:template name="children">
    <div>
      <xsl:attribute name="class">children <xsl:value-of select="@type" /></xsl:attribute>
      <h4 class="label"><xsl:value-of select="@type" /> children</h4>
      <ul>
        <xsl:for-each select="node">
          <li><xsl:apply-templates select="."/></li>
        </xsl:for-each>
      </ul>
    </div>
  </xsl:template>

  <!-- A program node -->
  <xsl:template name="program_node">
    <p>Program loaded from: <span class="input_name"><xsl:value-of select="@name" /></span></p>
  </xsl:template>

  <!-- A gobbet node -->
  <xsl:template name="gobbet_node">
    <p>A gobbet called: <span class="gobbet_name"><xsl:value-of select="@name" /></span></p>
  </xsl:template>

  <!-- A variable declaration node -->
  <xsl:template name="variabledeclaration_node">
    <p>Variable called: <span class="variable_declaration_name"><xsl:value-of select="@name" /></span></p>
  </xsl:template>

</xsl:stylesheet>
<!-- vim:sw=2:ts=2:et:autoindent  
  -->
