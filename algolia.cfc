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

      readHosts = [ 'https://#applicationId#.algolia.net/#apiVersion#' ];
      writeHosts = [ 'https://#applicationId#-dsn.algolia.net/#apiVersion#' ];

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

  //Indices
  /**
  * https://www.algolia.com/doc/rest-api/search/#add-an-object-without-id
  * https://www.algolia.com/doc/rest-api/search/#addupdate-an-object-by-id
  * @hint Add an object with or without an Id.
  * @content This is the objecting being added to the index. It can either be a struct or json
  */
  public struct function addObject( required string indexName, required any content, any objectId ) {
    if ( isNull( objectId ) )
      return apiCall( false, 'POST', '/indexes/#indexName#', {}, content );
    else
      return apiCall( false, 'PUT', '/indexes/#indexName#/#objectId#', {}, content );
  }

  /**
  * https://www.algolia.com/doc/rest-api/search/#batch-write-operations
  * @hint Add several Objects
  */
  public struct function addObjects( required string indexName, required array objects, string objectIdKey = 'objectID' ) {
    var requests = buildBatch( 'addObject', objects, true, objectIdKey );
    return batch( indexName, requests );
  }

  // public struct function getObject() {}

  // public struct function getObjects() {}

  // public struct function partialUpdateObject() {}

  // public struct function partialUpdateObjects() {}

  // public struct function saveObject() {}

  // public struct function saveObjects() {}

  // public struct function deleteObject() {}

  // public struct function deleteObjects() {}

  // public struct function deleteBy() {}

  // public struct function deleteByQuery() {}

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

  // public struct function waitTask() {}

  // public struct function getTaskStatus() {}

  // public struct function getSettings() {}

  // public struct function clearIndex() {}

  // public struct function setSettings() {}

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
        operation[ 'objectId' ] = object[ objectIdKey ];

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

    var queryString = parseQueryParams( queryParams, false );
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
        var encodedValue = encodeQueryParams && len( queryParams[ queryParamKey ] )
          ? encodeUrl( queryParams[ queryParamKey ] )
          : queryParams[ queryParamKey ];
        return queryString.listAppend( encodedKey & ( includeEmptyValues || len( encodedValue ) ? ( '=' & encodedValue ) : '' ), '&' );
      }, ''
    );

    return queryString.len() ? queryString : '';
  }

  private string function parseBody( required any body ) {
    if ( isStruct( body ) )
      return serializeJson( body );
    else if ( isJson( body ) )
      return body;
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