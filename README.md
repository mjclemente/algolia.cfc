# algolia.cfc
A CFML wrapper for the [Algolia Search API](https://www.algolia.com/doc/api-reference/). It currently supports most index-related methods, as well as a portion of the higher account-level methods.

### Acknowledgements

This project borrows heavily from the API frameworks built by [jcberquist](https://github.com/jcberquist), such as [xero-cfml](https://github.com/jcberquist/xero-cfml) and [aws-cfml](https://github.com/jcberquist/aws-cfml). Because it draws on those projects, it is also licensed under the terms of the MIT license.

## Table of Contents

- [Installation](#installation)
  - [Standalone Usage](#standalone-usage)
  - [Use as a ColdBox Module](#use-as-a-coldbox-module)
- [Quick Start for Sending](#quick-start)

## Installation
This wrapper can be installed as standalone component or as a ColdBox Module. Either approach requires a simple CommandBox command:

```
$ box install algoliacfc
```

If you can't use CommandBox, all you need to use this wrapper as a standalone component is the `algolia.cfc` file and the optional index helper component, located in `/helpers`; add them to your application wherever you store cfcs. But you should really be using CommandBox.

### Standalone Usage

CommandBox will install this component into a folder named `algoliacfc` within your current working directory; it can then be instantiated directly like so:

```cfc
algoliaClient = new path.to.algoliacfc.algolia( applicationId = 'xxx', apiKey = 'xxx' );
```

### Use as a ColdBox Module

To use the wrapper as a ColdBox Module you will need to pass the configuration settings in from your `config/Coldbox.cfc`. This is done within the `moduleSettings` struct:

```cfc
moduleSettings = {
  algoliacfc = {
    applicationId = 'xxx',
    apiKey = 'xxx'
  }
};
```

You can then leverage the CFC via the injection DSL: `algolia@algoliacfc`:

```
property name="algoliaClient" inject="algolia@algoliacfc";
```

## Quick Start

In 30 seconds, this quick start tutorial will show you how to index and search objects.

### Initialize the client

You first need to initialize the client. For that you need your **Application ID** and **API Key**. You can find both of them on your [Algolia account](https://www.algolia.com/api-keys).

```cfc
algoliaSearch = new algolia( applicationId = 'YourApplicationID', apiKey = 'YourAPIKey' );
```

### Push data
If you attempt to load data into an index that does not exist, Algolia will automatically create the index before populating it. Consequently, you can use the sample data provided in `members.json` to create and populate your first index, using the following code:

```cfc
members = deserializeJSON( fileRead( expandPath( 'members.json' ) ) ); //update path, based on your app setup
response = algoliaSearch.addObjects( 'members', members );
```

### Search

You can now search for members using first name, last name, company, etc. (even with typos):

```cfc
// search by first name
writeDump( var='#algoliaSearch.search( 'members', 'Constance' )#' );

// search a first name with typo
writeDump( var='#algoliaSearch.search( 'members', 'Constnce' )#' );

// search for a company
writeDump( var='#algoliaSearch.search( 'members', 'scentric' )#' );

// search for a first name and company
writeDump( var='#algoliaSearch.search( 'members', 'Constance Ziore' )#' );
```

### A Note About Working with Indices

Most of the official Algolia clients follow an Object Oriented pattern, requiring an *Index* object to be initialized in order to read/write from that index. Currently, this client does not have an *Index* object (so it doesn't need to be initialized). Instead, you need to include the name of the index with your requests. The operations available generally use the following format:

```cfc
algoliaSearch.operation( indexName, args );
```

There is an obvious convenience to having an *Index* object; you can initialize it once, and then you don't need to provide the `indexName` argument again. So adding an *Index* object is on the TODO list for this project.


### Frontend search

**Note:** If you are building a web application, Algolia recommends using their [JavaScript client](https://github.com/algolia/algoliasearch-client-javascript) to perform queries, for two primary reasons:

  * Your users get a better response time by not going through your servers
  * It will offload unnecessary tasks from your servers
  * (Also, why reinvent the wheel)
