<?xml version='1.0' encoding='ISO-8859-1' ?>
<!DOCTYPE helpset   
PUBLIC "-//Sun Microsystems Inc.//DTD JavaHelp HelpSet Version 2.0//EN"
         "http://java.sun.com/products/javahelp/helpset_2_0.dtd">

<helpset version="2.0">

  <!-- title -->
  <title>Quick Help</title>

  <!-- maps -->
  <maps>
     <homeID>intro</homeID>
     <mapref location="helpMap.jhm"/>
  </maps>

  <!-- views -->
  <view mergetype="javax.help.UniteAppendMerge">
    <name>TOC</name>
    <label>Table Of Contents</label>
    <type>javax.help.TOCView</type>
    <data>helpTOC.xml</data>
  </view>

  <view mergetype="javax.help.SortMerge">
    <name>Index</name>
    <label>Index</label>
    <type>javax.help.IndexView</type>
    <data>helpIndex.xml</data>
  </view>

  <view mergetype="javax.help.SortMerge">
    <name>Search</name>
    <label>Search</label>
    <type>javax.help.SearchView</type>
    <data engine="com.sun.java.help.search.DefaultSearchEngine">
      JavaHelpSearch
    </data>
  </view>

  <presentation default=true>
         <name>main window</name>
         <size width="400" height="500" />
         <location x="200" y="200" />
         <title>Quick Help</title>
         <toolbar>
             <helpaction>javax.help.BackAction</helpaction>
             <helpaction>javax.help.ForwardAction</helpaction>
         </toolbar>
     </presentation>

     <!-- This window is simpler than the main window.
       *  It's intended to be used a secondary window.
       *  It has no navigation pane or toolbar.
     -->
     <presentation displayviews=false>
         <name>secondary window</name>
         <size width="200" height="200" />
         <location x="200" y="200" />
     </presentation>

     <impl>
         <helpsetregistry helpbrokerclass="ui.utils.help.HHelpBroker" />
     </impl>
  
</helpset>

