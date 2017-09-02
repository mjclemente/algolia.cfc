/*
  Copyright (c) 2017, Matthew Clemente, John Berquist
  v0.2.0

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/
component output="false" displayname="algolia.cfc"  {

  public any function init(
    required string applicationId,
    required string apiKey,
    array hosts = [],
    string apiVersion = "1",
    boolean includeRaw = true ) {

    var readHosts = hosts;
    var writeHosts = hosts;

    if ( !hosts.len() ) {

      writeHosts = [ 'https://#applicationId#.algolia.net/#apiVersion#' ];
      readHosts = [ 'https://#applicationId#-dsn.algolia.net/#apiVersion#' ];

      var fallbackHosts = arrayMap( [1,2,3],
        function( item, index ) {
          return 'https://#applicationId#-#item#.algolianet.com/#apiVersion#';
        }
      );

      CreateObject( "java", "java.util.Collections" ).Shuffle( fallbackHosts );

      writeHosts.append( fallbackHosts, true );
      readHosts.append( fallbackHosts, true );

    }

    variables[ 'algolia' ] = {
      'applicationId' : applicationId,
      'apiKey' :  apiKey,
      'version' : apiVersion
    };

    variables[ 'originalWriteHosts' ] = writeHosts;
    variables[ 'originalReadHosts' ] = readHosts;
    variables[ 'writeHosts' ] = writeHosts;
    variables[ 'readHosts' ] = readHosts;
    variables[ 'readTimeout' ] = 2;
    variables[ 'writeTimeout' ] = 30;
    variables[ 'dnsTimerDelay' ] = 5 * 60; // 5 minutes
    variables[ 'dnsTimer' ] = now();
    variables[ 'includeRaw' ] = includeRaw;

    return this;
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#add-an-object-without-id
  * https://www.algolia.com/doc/rest-api/search/#addupdate-an-object-by-id
  * @hint Add an object with or without an Id.
  * @object This is the object being added to the index. It can either be a struct or json
  */
  public struct function addObject( required string indexName, required any object, any objectId ) {
    if ( isNull( objectId ) )
      return apiCall( false, 'POST', '/indexes/#indexName#', {}, object );
    else
      return apiCall( false, 'PUT', '/indexes/#indexName#/#objectId#', {}, object );
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#batch-write-operations
  * @hint Add several Objects
  */
  public struct function addObjects( required string indexName, required array objects, string objectIdKey = 'objectID' ) {
    var requests = buildBatch( 'addObject', objects, true, objectIdKey );
    return batch( indexName, requests );
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#retrieve-an-object
  * @hint Get an object from this index.
  */
  public struct function getObject( required string indexName, required string objectId, array attributesToRetrieve = [] ) {
    var params = {};
    if ( attributesToRetrieve.len() )
      params = { 'attributes' : attributesToRetrieve.toList( ',' ) };

    return apiCall( true, 'GET', '/indexes/#indexName#/#objectId#', params );
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#retrieve-multiple-objects
  * @hint Get several objects from this index.
  */
  public struct function getObjects( required string indexName, required array objectIds, array attributesToRetrieve = [] ) {
    var requests = [];

    var attributeList = '';
    if ( attributesToRetrieve.len() )
      attributeList = attributesToRetrieve.toList( ',' );

    for ( var objectId in objectIds ) {
      var operation = { 'indexName' : indexName, 'objectID' : objectId };
      if ( attributeList.len() )
        operation[ 'attributesToRetrieve' ] = attributeList;

      requests.append( operation );
    }

    return apiCall( true, 'POST', '/indexes/*/objects', {}, { 'requests' : requests } );
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#partially-update-an-object
  * @hint Update partially an object (only update attributes passed in argument).
  * @object contains the object attributes to override, the object must contains an objectID attribute
  * @createIfNotExists specifies whether or not a missing object must be created
  */
  public struct function partialUpdateObject( required string indexName, required any object, boolean createIfNotExists = true ) {
    var params = createIfNotExists ? {} : { 'createIfNotExists' : false };

    return apiCall( false, 'POST', '/indexes/#indexName#/#object.objectId#/partial', params, object );
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#batch-write-operations
  * @hint Partially Override the content of several objects.
  * @objects contains an array of objects to update (each object must contains a objectID attribute)
  */
  public struct function partialUpdateObjects( required string indexName, required array objects, string objectIdKey = 'objectID', boolean createIfNotExists = true ) {

    if ( createIfNotExists )
      var requests = buildBatch( 'partialUpdateObject', objects, true, objectIdKey );
    else
      var requests = buildBatch( 'partialUpdateObjectNoCreate', objects, true, objectIdKey );

    return batch( indexName, requests );
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#addupdate-an-object-by-id
  * @hint Override the content of object. Basically the same add addObject, with an objectId provided
  * @object This is the object being added to the index. It can either be a struct or json
  */
  public struct function saveObject( required string indexName, required any object, string objectIDKey = 'objectID' ) {
    return apiCall( false, 'PUT', '/indexes/#indexName#/#object[ objectIDKey ]#', {}, object );
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#batch-write-operations
  * @hint Override the content of several objects.
  * @objects contains an array of objects to update (each object must contains a objectID attribute)
  */
  public struct function saveObjects( required string indexName, required array objects, string objectIdKey = 'objectID' ) {
    var requests = buildBatch( 'updateObject', objects, true, objectIdKey );
    return batch( indexName, requests );
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#delete-an-object
  * @hint Delete an object from the index.
  */
  public struct function deleteObject( required string indexName, required string objectID ) {
    return apiCall( false, 'DELETE', '/indexes/#indexName#/#objectID#' );
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#batch-write-operations
  * @hint Delete several objects.
  * @objects contains an array of objectIDs to delete.
  */
  public struct function deleteObjects( required string indexName, required array objects ) {
    var objectIds = [];
    for ( var id in objects ) {
      objectIds.append( { 'objectID' : id } );
    }
    var requests = buildBatch( 'deleteObject', objectIds, true );
    return batch( indexName, requests );
  }


  /**
  * https://www.algolia.com/doc/rest-api/search/#delete-by-query
  * @hint Delete all objects matching a query.
  * This endpoint doesn’t support all the options of a query, only its filters (numeric, facet, or tag) and geo queries. It also doesn’t accept empty filters or query.
  *
  * It appears that the previous deleteByQuery method implemented by most clients involved manually writing a query and then deleting the ids that were returned (via internally calling deleteObjects()), some have deprecated this approach
  */
  public struct function deleteBy( required string indexName, required struct args ) {
    var params = { 'params': parseQueryParams( args ) };
    return apiCall( false, 'POST', '/indexes/#indexName#/deleteByQuery', {}, params );
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#batch-write-operations
  * @hint Delete all objects matching a query.
  * Actually justs browses the query and then delegates to deleteObjects() to perform the deletes, based on the objectIds returned by the query results
  * While there is now a specific endpoint for deleteByQuery, it seems this approach offers significantly more flexibility, so it's worth providing
  *
  * NOTE: This is a convenience method that involves multiple requests to the API. The HTTP data returned is from the final search request. To do this we need to track the results of each request separately from the data we're actually using. Not thrilled with this, but it works.
  *
  * The data key returned is a struct with an array of the objectIDs deleted
  *
  */
  public struct function deleteByQuery( required string indexName, required string query, struct args = {} ) {

    args[ 'attributesToRetrieve' ] = 'objectID';
    args[ 'hitsPerPage' ] = 1000;
    args[ 'distinct' ] = false;

    var deletedObjectIds = [];
    var result = search( indexName, query, args );
    var results = result.data;

    while ( results[ 'nbHits' ] ) {
      var objectIDs = [];
      for ( var record in results[ 'hits' ] ) {
        objectIDs.append( record[ 'objectID' ] );
      }

      var deleteRequest = deleteObjects( indexName, objectIDs ).data;
      waitTask( indexName, deleteRequest[ 'taskID' ] );
      deletedObjectIds.append( objectIDs, true );

      result = search( indexName, query, args );
      results = result.data;
    }
    result[ 'data' ] = { 'objectIDs' : deletedObjectIds }; //overwrite the data with the deleted objects that we've tracked

    return result;
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#search-an-index
  * @hint Search inside an index.
  */
  public struct function search( required string indexName, required string query, struct args = {} ) {
    args[ 'query' ] = query;
    var params = { 'params': parseQueryParams( args ) };
    return apiCall( true, 'POST', '/indexes/#indexName#/query', {}, params );
  }

  // public struct function searchForFacetValues() {}

  // public struct function searchDisjunctiveFaceting() {}

  /**
  * https://www.algolia.com/doc/rest-api/search/#get-a-tasks-status
  * @hint Wait the publication of a task on the server.
  * All server task are asynchronous and you can check with this method that the task is published.
  * @timeBeforeRetry the time in milliseconds before retry (default = 100ms)
  */
  public struct function waitTask( required string indexName, required string taskID, numeric timeBeforeRetry = 100 ) {
    var taskPending = true;
    var result = {};
    while ( taskPending ) {
      result = getTaskStatus( indexName, taskID ).data;
      if ( result[ 'status' ] == 'published' )
        taskPending = false;
      else
        sleep( timeBeforeRetry );
    }
    return result;
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#get-a-tasks-status
  * @hint get the status of a task on the server.
  * All server task are asynchronous and you can check with this method that the task is published or not.
  */
  public struct function getTaskStatus( required string indexName, required string taskID ) {
    return apiCall( true, 'GET', '/indexes/#indexName#/task/#taskID#' );
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#get-index-settings
  * https://www.algolia.com/doc/rest-api/search/#backward-compatibility
  * @hint Get settings of this index.
  * Synonyms were originally set via the index settings, and a Get settings call would return all synonyms as part of the settings JSON data. This behavior has been kept to maintain backward compatibility.
  * Because we do not want synonyms to be included in our settings, we getVersion=2 to the request as a query parameter:
  */
  public struct function getSettings( required string indexName ) {
    var params = { 'getVersion' : 2 };
    return apiCall( true, 'GET', '/indexes/#indexName#/settings', params );
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#clear-index
  * @hint This function deletes the index content. Settings and index specific API keys are kept untouched.
  */
  public struct function clearIndex( required string indexName ) {
    return apiCall( false, 'POST', '/indexes/#indexName#/clear' );
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#change-index-settings
  * @hint Set settings for this index.
  * Documentation states that "Specifying null for a setting resets it to its default value." This is not true for all settings. For example, 'hitsPerPage' requires a value. I don't have have a list of settings that require values.
  * To pass in null for CFML, use `javaCast( "null", "" )`
  */
  public struct function setSettings( required string indexName, required struct settings, boolean forwardToReplicas = false ) {
    var params = {};
    if ( forwardToReplicas )
      params = { 'forwardToReplicas' : true };

    return apiCall( false, 'PUT', '/indexes/#indexName#/settings', params, settings );
  }

  // public struct function listApiKeys() {}

  // public struct function listUserKeys() {}

  // public struct function getUserKeyACL() {}

  // public struct function getApiKey() {}

  // public struct function deleteApiKey() {}

  // public struct function deleteUserKey() {}

  // public struct function addApiKey() {}

  // public struct function addUserKey() {}

  // public struct function updateApiKey() {}

  // public struct function updateUserKey() {}

  /**
  * https://www.algolia.com/doc/rest-api/search/#batch-write-operations
  * @hint Send a batch request.
  */
  public struct function batch( required string indexName, required struct requests ) {
    //python client checks if requests is a list/array. If so, it transforms to struct with 'requests' key. Worthwhile?
    return apiCall( false, 'POST', '/indexes/#indexName#/batch', {}, requests );
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#batch-write-operations
  * @hint Takes the array of objects and returns the requests array for batch operations.
  * @action the batch action
  * @withObjectId indicates if the batch write operation utilizes the objectId
  */
  private struct function buildBatch( required string action, required array objects, required boolean withObjectId, string objectIdKey = 'objectID' ) {
    var requests = [];
    for ( var object in objects ) {
      var operation = { 'action' : action, 'body' : object };
      if ( withObjectId && object.keyExists( objectIdKey ) )
        operation[ 'objectID' ] = object[ objectIdKey ];

      requests.append( operation );
    }

    return { 'requests' : requests };
  }

  // public struct function browseFrom() {}

  // public struct function searchSynonyms() {}

  // public struct function getSynonym() {}

  // public struct function deleteSynonym() {}

  // public struct function clearSynonyms() {}

  // public struct function batchSynonyms() {}

  // public struct function saveSynonym() {}

  // public struct function searchFacet() {}

  // public struct function searchRules() {}

  // public struct function getRule() {}

  // public struct function deleteRule() {}

  // public struct function clearRules() {}

  // public struct function batchRules() {}

  // public struct function saveRule() {}


  //List indexes
  public struct function listIndexes( numeric page ) {
    return apiCall( true, 'GET', '/indexes' );
  }

  // API CALL RELATED PRIVATE FUNCTIONS
  private struct function apiCall(
    required boolean isRead,
    required string httpMethod,
    required string path,
    struct queryParams = { },
    any body = '',
    struct headers = { } )  {

    var queryString = parseQueryParams( queryParams );
    headers.append( getBaseHttpHeaders(), true );
    var requestHeaders = parseHeaders( headers );
    var requestBody = parseBody( body );
    var timeout = isRead ? variables.readTimeout : variables.writeTimeout;

    var hosts = getHosts( isRead );
    var exceptions = [];

    var requestStart = getTickCount();

    for ( var host in hosts ) {

      var result = makeHttpRequest( httpMethod, host, path, queryString, requestHeaders, requestBody, timeout );
      result[ 'responseTime' ] = getTickCount() - requestStart;

      if ( result.statusClass == 2 ) {
        //if it's a 200, return
        return result;

      } else if ( result.statusClass == 4 && result.keyExists( 'message' ) ) {
        //if it's a 400 from Algolia, throw error
        writeDump( var='#result#', format='html', abort='true' );
        throw( result.message, 'AlgoliaException', '#httpMethod# request to #host##path## queryString# resulted in #result.statusText#' , result.statusCode );

      } else {
        //other responses (408 Request Timeout, 500 Server Error, 0 Connection Failure) indicate some issue with the host.
        rotateHosts( isRead );
        exceptions.append( '#host# (#result.statusCode# #result.statusText#)' );

      }
    }
    //if we've made it to the end of the loop, it means that all hosts failed :-(
    throw( 'Hosts unreachable', 'AlgoliaException', exceptions.toList( ', ' ) );
  }

  private struct function getBaseHttpHeaders() {
    return {
      'Content-Type' : 'application/json',
      'User-Agent' : 'algolia.cfc',
      'X-Algolia-Application-Id' : variables.algolia.applicationId,
      'X-Algolia-API-Key' : variables.algolia.apiKey
    };
  }

  private struct function makeHttpRequest(
    required string httpMethod,
    required string host,
    required string path,
    string queryString = '',
    array requestHeaders = [],
    any requestBody = '',
    numeric timeout = 0
  ) {
    var apiResponse = {};
    var result = {};

    var fullPath = host & path & ( queryString.len() ? '?#queryString#' : '' );

    cfhttp( url = fullPath, method = httpMethod, result = 'apiResponse', timeout = timeout ) {
      for ( var header in requestHeaders ) {
        cfhttpparam( type = "header", name = header.name, value = header.value );
      }
      if ( arrayFindNoCase( [ 'POST','PUT' ], httpMethod ) && isJSON( requestBody ) )
        cfhttpparam( type = "body", value = requestBody );
    }

    result[ 'statusCode' ] = val( apiResponse.statuscode );
    result[ 'statusClass' ] = val( apiResponse.statuscode )
      ? fix( result.statusCode / 100 )
      : 5;

    result[ 'statusText' ] = val( apiResponse.statuscode )
      ? listRest( apiResponse.statuscode, ' ' )
      : apiResponse.statuscode & ' ' & apiResponse.ErrorDetail ;

    var deserializedFileContent = {};

    if ( isJson( apiResponse.fileContent ) )
      deserializedFileContent = deserializeJSON( apiResponse.fileContent );

    if ( apiResponse.statuscode >= 400 ) {
      if ( isStruct( deserializedFileContent ) )
        result.append( deserializedFileContent );
    } else {
      //stored in data, because some responses are arrays and others are structs
      result[ 'data' ] = deserializedFileContent;
    }

    if ( variables.includeRaw ) {
      result[ 'raw' ] = {
        'method' : httpMethod.ucase(),
        'path' : fullPath,
        'params' : queryString,
        'response' : apiResponse.fileContent,
        'responseHeaders' : apiResponse.responseheader
      };
    }

    return result;
  }

  /**
  * @hint convert the headers from a struct to an array
  */
  private array function parseHeaders( required struct headers ) {
    var sortedKeyArray = headers.keyArray();
    sortedKeyArray.sort( 'textnocase' );
    var processedHeaders = sortedKeyArray.map(
      function( key ) {
        return { name: key, value: trim( headers[ key ] ) };
      }
    );
    return processedHeaders;
  }

  /**
  * @hint converts the queryparam struct to a string, with optional encoding and the possibility for empty values being pass through as well
  */
  private string function parseQueryParams( required struct queryParams, boolean encodeQueryParams = true, boolean includeEmptyValues = true ) {
    var sortedKeyArray = queryParams.keyArray();
    sortedKeyArray.sort( 'text' );

    var queryString = sortedKeyArray.reduce(
      function( queryString, queryParamKey ) {
        var encodedKey = encodeQueryParams
          ? encodeUrl( queryParamKey )
          : queryParamKey;
        if ( !isArray( queryParams[ queryParamKey ] ) ) {
          var encodedValue = encodeQueryParams && len( queryParams[ queryParamKey ] )
            ? encodeUrl( queryParams[ queryParamKey ] )
            : queryParams[ queryParamKey ];
        } else {
          var encodedValue = encodeQueryParams && ArrayLen( queryParams[ queryParamKey ] )
            ?  encodeUrl( serializeJSON( queryParams[ queryParamKey ] ) )
            : queryParams[ queryParamKey ].toList();
          }
        return queryString.listAppend( encodedKey & ( includeEmptyValues || len( encodedValue ) ? ( '=' & encodedValue ) : '' ), '&' );
      }, ''
    );

    return queryString.len() ? queryString : '';
  }

  /**
  * @hint Algolia claims the objectId can be a string or integer, but the documentation to retrieve multiple objects (https://www.algolia.com/doc/rest-api/search/#retrieve-multiple-objects) requests it as a string and requests to that endpoint fail when an integer is passed. We'll just convert those to strings, unless we return into problems elsewhere.
  */
  private string function parseBody( required any body ) {
    if ( isStruct( body ) )
      return serializeJson( body ).reReplaceNoCase( '"(objectID)":\s?([\d]+)', '"\1":"\2"', 'all' );
    else if ( isJson( body ) )
      return body.reReplaceNoCase( '"(objectID)":\s?([\d]+)', '"\1":"\2"', 'all' );
    else
      return '';
  }

  private string function encodeUrl( required string str, boolean encodeSlash = true ) {
    var result = replacelist( urlEncodedFormat( str, 'utf-8' ), '%2D,%2E,%5F,%7E', '-,.,_,~' );
    if ( !encodeSlash ) result = replace( result, '%2F', '/', 'all' );

    return result;
  }

  /**
  * @hint We prefer the original hosts, because they keep the primary read host and write host first. If there is a failure, the non-original hosts are rotated and that array is used, until the DNS timer says it's safe to try the original hosts again
  */
  private array function getHosts( required boolean isRead ) {
    var secondsSinceRotate = variables.dnsTimer.diff( 's', now() );

    if ( isRead ) {

      if ( secondsSinceRotate < variables.dnsTimerDelay )
        return variables.readHosts;
      else
        return variables.originalReadHosts;

    } else {

      if ( secondsSinceRotate < variables.dnsTimerDelay )
        return variables.writeHosts;
      else
        return variables.originalWriteHosts;

    }

  }

  /**
  * @hint read and write separated, because while the read and write fallback hosts are the same, the primary read and write hosts are different, so we don't necessarily want to rotate both because only one failed
  */
  private void function rotateHosts( required boolean isRead ) {
    variables.dnsTimer = now();
    if ( isRead )
      CreateObject( "java", "java.util.Collections" ).Rotate( variables.readHosts, -1 );
    else
      CreateObject( "java", "java.util.Collections" ).Rotate( variables.writeHosts, -1 );
  }

}