# ElasticsearchClient - A Swift package for Elasticsearch

[![Build Status][image-1]][1] [![Swift Version][image-2]][2]

The package offers a set of API's to make searching in Elasticsearch easier. It also support signing V4 requests for AWS.

### What it's for
Say I have a Swift type OfficialPublication, corresponding to an indexed type in Elasticsearch:
```swift
let fetcher = ElasticsearchFetcher<OfficialPublication>(withFilters: OfficialPublication.query(forSearchText: "quantum entanglement")
fetcher.didFetchDocuments = { officialDocuments in
	
}
```

### Setup
By default, the client will use `http://localhost:9200` as the default root, you can modify it as such:
```swift
import ElasticsearchClient
ElasticsearchClient.initialize(withRootURL: "http://localhost:9200")
```
You can also setup the client to connect to an AWS instance:
```swift
ElasticsearchClient.initialize(withRootURL: "http://search-esa-cern-ers1-vkzyt8wegfb2ah652a924fsbhq.us-east-1.es.amazonaws.com",
                               signatureType: .awsV4,
                               awsRegion: "us-east-1",
                               awsAccessKey: "NOTHISISNOTMYAWSACCESSKEY",
                               awsSecretKey: "OFCOURSETHISISNOTMYREALAWSSECRETKEY")
```
Every request with the ElasticsearchClient uses an elasticsearch type name. The client, however is unaware of the index name to use (unless the API had it in its parameter), you just provide it by setting up the following callback before making any call:
```swift
ElasticsearchClient.indexNameForTypeName = { typeName -> String in
    switch typeName {
    case "authors":
        return "index_name_for_authors"
    case "organizations":
        return "index_name_for_organizations"
    case "officialPublications":
        return "index_name_for_official_publications"
    default:
        break
    }
    return typeName
}
```
### Basic Calls
Fetch a document by it's id:
```swift
ElasticsearchCall.fetchDocumentSource(typeName: "officialPublications", id: 3987525) { (response: ElasticsearchAsyncResult<JSON>) in
    do {
        let document = try response.resolve()
        print("Got document: \(document)")
    }
    catch {
        print("Bummer, that didn't work: \(error)")
    }
}
```
If you noticed the `JSON` type there, ElasticsearchClient uses [Gloss](https://github.com/hkellaway/Gloss) as a dependency, check it out!

Fetch documents with a search query:
```swift
// Define your Elasticsearch query.
let query: JSON = ["query": ["bool": ["should":...]], "sort": [["_score": "asc"]]

ElasticsearchCall.search(indexName: "index_name", typeName: "typeName", query: query)  { (response: ElasticsearchAsyncResult<JSON>) in
    do {
        let hits = try response.resolve()
        print("Got hits: \(hits)")
    }
    catch {
        print("Bummer, that didn't work: \(error)")
    }
}
```







[1]:    https://travis-ci.org/amorican/ElasticsearchClient
[2]:    https://swift.org "Swift"

[image-1]:  https://travis-ci.org/amorican/ElasticsearchClient.svg
[image-2]:  https://img.shields.io/badge/swift-version%203-blue.svg