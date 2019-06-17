package main

import (
    "flag"
    "fmt"
    "math"
    "os"
    "strconv"
    "strings"
    "sync"
    "time"

    "gocbcore"

)

// A very simple DCP client for demonstrating the use of collections with gocbcore DCP. This work is WIP. To stop the application use
// SIGINT which will cause a graceful shutdown.

type streamObserver struct {
    endWg sync.WaitGroup
}

func (so *streamObserver) SnapshotMarker(startSeqNo, endSeqNo uint64, vbId uint16, streamId uint16,
    snapshotType gocbcore.SnapshotState) {

    fmt.Printf("Snapshot received on vbId %d, streamId %d, type %d\n", vbId, streamId, snapshotType)
}

func (so *streamObserver) Mutation(seqNo, revNo uint64, flags, expiry, lockTime uint32, cas uint64, datatype uint8, vbId uint16,
    collectionId uint32, streamId uint16, key, value []byte) {

    fmt.Printf("Mutation received on vbId %d, streamId %d for collection %d, key %s\n", vbId, streamId, collectionId, key)
}

func (so *streamObserver) Deletion(seqNo, revNo, cas uint64, datatype uint8, vbId uint16, collectionId uint32, streamId uint16,
    key, value []byte) {

    fmt.Println("Deletion")
}

func (so *streamObserver) Expiration(seqNo, revNo, cas uint64, vbId uint16, collectionId uint32, streamId uint16, key []byte) {
    fmt.Println("Expiration")
}

func (so *streamObserver) End(vbId uint16, streamId uint16, err error) {
    fmt.Printf("Received stream end. Stream complete with reason %d\n", gocbcore.GetStreamEndValue(err))
    so.endWg.Done()
}

func (so *streamObserver) CreateCollection(seqNo uint64, version uint8, vbId uint16, manifestUid uint64, scopeId uint32,
    collectionId uint32, ttl uint32, streamId uint16, key []byte) {

    fmt.Printf("Received CreateCollection for vb %d on stream %d. Collection Id: %d, Collection name: %s\n", vbId, streamId, collectionId, string(key))
}

func (so *streamObserver) DeleteCollection(seqNo uint64, version uint8, vbId uint16, manifestUid uint64, scopeId uint32, collectionId uint32,
    streamId uint16) {

    fmt.Printf("Received CollectionDROPPED, id:%x for vb %d\n", collectionId, vbId)
}

// FlushCollection(seqNo uint64, version uint8, vbId uint16, manifest_uid uint64, collection_id uint32) // Not yet existing

func (so *streamObserver) CreateScope(seqNo uint64, version uint8, vbId uint16, manifestUid uint64, scopeId uint32,
    streamId uint16, key []byte) {

    fmt.Printf("Received CreateScope for vb %d. Scope Id: %d Scope name: %s\n", vbId, scopeId, string(key))
}

func (so *streamObserver) DeleteScope(seqNo uint64, version uint8, vbId uint16, manifestUid uint64, scopeId uint32,
    streamId uint16) {

    fmt.Printf("Received ScopeDROPPED, id:%x for vb %d\n", scopeId, vbId)
}

func (so *streamObserver) ModifyCollection(seqNo uint64, version uint8, vbId uint16, manifestUid uint64,
    collectionId uint32, ttl uint32, streamId uint16) {

    fmt.Printf("Received ModifyCollection for vb %d. Collection Id: %d\n", vbId, collectionId)
}

func main() {
    server := flag.String("server", "", "The connection string to connect to")
    user := flag.String("user", "", "The username to use to authenticate")
    password := flag.String("password", "", "The password to use to authenticate")
    bucketName := flag.String("bucket", "default", "The bucket to use")
    vbuckets := flag.String("vbuckets", "", "The vbucket's to create streams for (can be of form 1 or 1:20)")
    collections := flag.Bool("collections", false, "Enable collections on the stream")
    streamIdScope := flag.String("enable-stream-id-scope", "", "Scope-ID for a stream-id DCP stream, will listen to scope x")
    streamIdCollection := flag.String("enable-stream-id-collection", "", "Collection-ID for a stream-id DCP stream, will listen to collection x")
    streamScope := flag.String("enable-scope", "", "An ID for a for scope x")
    streamCollection := flag.String("enable-collection", "", "An ID for collection x")
    flag.Parse()

    if len(*streamScope) > 0 && len(*streamCollection) > 0 {
        fmt.Printf("Invalid usage of -enable-scope and -enable-collection\n")
        return;
    }

    vbucketIds, err := parseVbucketIds(*vbuckets)
    if err != nil {
        panic(err)
    }

    agentConfig := &gocbcore.AgentConfig{
        ConnectTimeout:       60000 * time.Millisecond,
        ServerConnectTimeout: 7000 * time.Millisecond,
        NmvRetryDelay:        100 * time.Millisecond,
        UseKvErrorMaps:       true,
        BucketName:           *bucketName,
        Username:             *user,
        Password:             *password,
        UseCollections:       *collections,
        UseDurations:         true,
        EnableStreamId:       len(*streamIdScope) + len(*streamIdCollection) > 0,
    }

    err = agentConfig.FromConnStr(*server)
    if err != nil {
        panic(err)
    }

    dcpAgent, err := gocbcore.CreateDcpAgent(agentConfig, "dcp_stream_" + string(os.Getpid()), gocbcore.DcpOpenFlagProducer)
    if err != nil {
        panic(err)
    }

    observer := &streamObserver{}

  //  waitCh := make(chan error)
  //  stop := make(chan os.Signal, 1)
 //   signal.Notify(stop, os.Interrupt)

    // Create a stream-ID stream listening to the scope
    if len(*streamIdScope) > 0 {
        // Create a filter to focus on only one collection initially and give it stream id 1 so that we can later open another stream
        // with a different filter on the same vbuckets.
        // If we wanted to get changes for all collections on a scope we would set Scope instead of Collections (we cannot set both or the server will error).
        // Collection ids in filters are hex based strings without leading 0x, we may change gocbcore to hide this and accept uint.
        filter := &gocbcore.CollectionStreamFilter{
            Scope: *streamIdScope,
            StreamId: 99,
        }

        for _, vbId := range vbucketIds {
            observer.endWg.Add(1)
            _, err := dcpAgent.OpenCollectionStream(vbId, gocbcore.DcpStreamAddFlagActiveOnly, 0, 0, math.MaxInt64, 0, 0,
                observer, filter, func(entries []gocbcore.FailoverEntry, cbErr error) {
                    fmt.Printf("Open received for vb %d\n", vbId)
                    if cbErr != nil {
                        panic(cbErr)
                    }
                })
            if err != nil {
                panic(err)
            }
        }
    }

    // Create a stream listening to the scope
    if len(*streamScope) > 0 {
        // Create a filter to focus on only one collection initially and give it stream id 1 so that we can later open another stream
        // with a different filter on the same vbuckets.
        // If we wanted to get changes for all collections on a scope we would set Scope instead of Collections (we cannot set both or the server will error).
        // Collection ids in filters are hex based strings without leading 0x, we may change gocbcore to hide this and accept uint.
        filter := &gocbcore.CollectionStreamFilter{
            Scope: *streamScope,
        }

        for _, vbId := range vbucketIds {
            observer.endWg.Add(1)
            _, err := dcpAgent.OpenCollectionStream(vbId, gocbcore.DcpStreamAddFlagActiveOnly, 0, 0, math.MaxInt64, 0, 0,
                observer, filter, func(entries []gocbcore.FailoverEntry, cbErr error) {
                    fmt.Printf("Open received for vb %d\n", vbId)
                    if cbErr != nil {
                        panic(cbErr)
                    }
                })
            if err != nil {
                panic(err)
            }
        }
    }

    // Create a stream-ID stream listening to the scope
    if len(*streamIdCollection) > 0 {
        // Create a new filter for the new collection, with a different stream id.
        filter := &gocbcore.CollectionStreamFilter{
            Collections: []string{*streamIdCollection},
            StreamId: 199,
        }

        for _, vbId := range vbucketIds {
            observer.endWg.Add(1)
            _, err := dcpAgent.OpenCollectionStream(vbId, gocbcore.DcpStreamAddFlagActiveOnly, 0, 0, math.MaxInt64, 0, 0,
                observer, filter, func(entries []gocbcore.FailoverEntry, cbErr error) {
                    fmt.Printf("Open received for vb %d\n", vbId)
                    if cbErr != nil {
                        fmt.Println(cbErr.Error())
                    }
                })
            if err != nil {
                panic(err)
            }
        }
    }

    // Create a stream-ID stream listening to the scope
    if len(*streamCollection) > 0 {
        // Create a new filter for the new collection, with a different stream id.
        filter := &gocbcore.CollectionStreamFilter{
            Collections: []string{*streamCollection},
        }

        for _, vbId := range vbucketIds {
            observer.endWg.Add(1)
            _, err := dcpAgent.OpenCollectionStream(vbId, gocbcore.DcpStreamAddFlagActiveOnly, 0, 0, math.MaxInt64, 0, 0,
                observer, filter, func(entries []gocbcore.FailoverEntry, cbErr error) {
                    fmt.Printf("Open received for vb %d\n", vbId)
                    if cbErr != nil {
                        fmt.Println(cbErr.Error())
                    }
                })
            if err != nil {
                panic(err)
            }
        }
    }

    // Create a normal stream if no filtered stream enabled
    if len(*streamCollection) + len(*streamScope) + len(*streamIdCollection) + len(*streamIdScope) == 0 {
        for _, vbId := range vbucketIds {
            observer.endWg.Add(1)
            _, err := dcpAgent.OpenCollectionStream(vbId, gocbcore.DcpStreamAddFlagActiveOnly, 0, 0, math.MaxInt64, 0, 0,
                observer, nil, func(entries []gocbcore.FailoverEntry, cbErr error) {
                    fmt.Printf("Open received for vb %d\n", vbId)
                    if cbErr != nil {
                        fmt.Println(cbErr.Error())
                    }
                })
            if err != nil {
                panic(err)
            }
        }
    }

    // Wait for SIGINT
  //  select {
 //   case <-waitCh:
  //  case <-stop:
  //      close(waitCh)
  //  }

    observer.endWg.Wait()

    dcpAgent.Close()
}

func parseVbucketIds(vbuckets string) ([]uint16, error) {
    var vbucketIds []uint16
    splitIds := strings.Split(vbuckets, ":")
    startId, err := strconv.Atoi(splitIds[0])
    if err != nil {
        return nil, err
    }
    vbucketIds = append(vbucketIds, uint16(startId))
    if len(splitIds) > 1 {
        endId, err := strconv.Atoi(splitIds[1])
        if err != nil {
            return nil, err
        }

        for i := startId + 1; i <= endId; i++ {
            vbucketIds = append(vbucketIds, uint16(i))
        }
    }

    return vbucketIds, nil
}
