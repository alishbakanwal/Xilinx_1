<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html"/>

<xsl:template match="RootFolder">
   <h1><a name="{generate-id()}"><xsl:value-of select="./@label"/></a></h1>
   <xsl:apply-templates/>
</xsl:template>

<xsl:template match="Folder">
   <h2><a name="{generate-id()}"><xsl:value-of select="./@label"/></a></h2>
   <xsl:apply-templates/>
</xsl:template>

<xsl:template match="SubFolder">
   <h3><a name="{generate-id()}"><xsl:value-of select="./@label"/></a></h3>
   <xsl:apply-templates/>
</xsl:template>

<xsl:template match="Template">
   <title><xsl:value-of select="./@SubFolder"/></title>
   <body>
      <h4><a name="{generate-id()}"><xsl:value-of select="./@label"/></a></h4>
      <table border="1"><td><pre><xsl:apply-templates/></pre></td></table>
   </body>
</xsl:template>

</xsl:stylesheet>

