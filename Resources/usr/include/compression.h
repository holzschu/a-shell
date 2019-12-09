#ifndef __COMPRESSION_HEADER__
#define __COMPRESSION_HEADER__

#include <stdint.h>
#include <os/base.h>
#include <sys/types.h>
#include <Availability.h>

#ifdef __cplusplus
extern "C" {
#endif

#if __has_feature(assume_nonnull)
/*  If assume_nonnull is available, use it and use nullability qualifiers.    */
    _Pragma("clang assume_nonnull begin")
#else
/*  Otherwise, neuter the nullability qualifiers.                             */
#   define __nullable
#endif
  
/*!
 @enum compression_algorithm
 
 @abstract Tag used to select a compression algorithm.
 
 @discussion libcompression supports a number of different compression
 algorithms, but we have only implemented algorithms that we believe are the
 best choice in some set of circumstances; there are many, many compression
 algorithms that we do not provide because using one of the algorithms we
 do provide is [almost] always a better choice.
 
 There are three commonly-known encoders implemented: LZ4, zlib (level 5), and
 LZMA (level 6).  If you require that your compression be interoperable with
 non-Apple devices, you should use one of these three schemes:
 
    - Use LZ4 if speed is critical, and you are willing to sacrifice
    compression ratio to achieve it.
 
    - Use LZMA if compression ratio is critical, and you are willing to
    sacrifice speed to achieve it.  (Note: the performance impact of making
    this choice cannot be overstated.  LZMA is an order of magnitude slower
    for both compression and decompression than other schemes).
 
    - Use zlib otherwise.
 
 If you do not require interoperability with non-Apple devices, use LZFSE
 in the place of zlib in the hierarchy above.  It is an Apple-developed
 algorithm that is faster than, and generally compresses better than zlib.
 It is slower than LZ4 and does not compress as well as LZMA, however, so
 you will still want to use those algorithms in the situations described.

 Further details on the supported public formats, and their implementation
 in the compression library:
 
 - LZ4 is an extremely high-performance compressor.  The open source version
   is already one of the fastest compressors of which we are aware, and we
   have optimized it still further in our implementation.  The encoded format
   we produce and consume is compatible with the open source version, except
   that we add a very simple frame to the raw stream to allow some additional
   validation and functionality.
 
   The frame is documented here so that you can easily wrap another LZ4
   encoder/decoder to produce/consume the same data stream if necessary.  An
   LZ4 encoded buffer is a sequence of blocks, each of which begins with a
   header.  There are three possible headers:
 
        a "compressed block header" is (hex) 62 76 34 31, followed by the
        size in bytes of the decoded (plaintext) data represented by the
        block and the size (in bytes) of the encoded data stored in the
        block.  Both size fields are stored as (possibly unaligned) 32-bit
        little-endian values.  The compressed block header is followed
        immediately by the actual lz4-encoded data stream.
 
        an "uncompressed block header" is (hex) 62 76 34 2d, followed by the
        size of the data stored in the uncompressed block as a (possibly
        unaligned) 32-bit little-endian value.  The uncompressed block header
        is followed immediately by the uncompressed data buffer of the
        specified size.
 
        an "end of stream header" is (hex) 62 76 34 24, and marks the end
        of the lz4 frame.  No further data may be written or read beyond 
        this header.
 
   If you are implementing a wrapper for a raw LZ4 decoder, keep in mind that
   a compressed block may reference data from the previous block, so the
   (decoded) previous block must be available to the decoder.
 
 - We implement the LZMA level 6 encoder only.  This is the default compression
   level for open source LZMA, and provides excellent compression.  The LZMA
   decoder supports decoding data compressed with any compression level.
 
 - We implement the zlib level 5 encoder only.  This compression level provides
   a good balance between compression speed and compression ratio.  The zlib
   decoder supports decoding data compressed with any compression level.

   The encoded format is the raw DEFLATE format as described in IETF RFC 1951.
   Using the ZLIB library, the equivalent configuration of the encoder would be
   obtained with a call to:

        deflateInit2(zstream,5,Z_DEFLATED,-15,8,Z_DEFAULT_STRATEGY)

 - LZ4_RAW is supported by the buffer APIs only, and encodes/decodes payloads
   compatible with the LZ4 library, without the frame headers described above.
 
*/
typedef enum {

    /* Commonly-available algorithms */
    COMPRESSION_LZ4      = 0x100,       // available starting OS X 10.11, iOS 9.0
    COMPRESSION_ZLIB     = 0x205,       // available starting OS X 10.11, iOS 9.0
    COMPRESSION_LZMA     = 0x306,       // available starting OS X 10.11, iOS 9.0
    COMPRESSION_LZ4_RAW  = 0x101,       // available starting OS X 10.11, iOS 9.0

    /* Apple-specific algorithm */
    COMPRESSION_LZFSE    = 0x801,       // available starting OS X 10.11, iOS 9.0

} compression_algorithm;

/******************************************************************************
 * Raw buffer compression interfaces                                          *
 ******************************************************************************/

/*!

 @function compression_encode_scratch_buffer_size

 @abstract
 Get the minimum scratch buffer size for the specified compression algorithm encoder.

 @param algorithm
 The compression algorithm for which the scratch space will be used.

 @return
 The number of bytes to allocate as a scratch buffer for use to encode with the specified
 compression algorithm. This number may be 0.

*/
extern size_t
compression_encode_scratch_buffer_size(compression_algorithm algorithm)
__API_AVAILABLE(macos(10.11), ios(9.0));

/*!

 @function compression_encode_buffer

 @abstract
 Compresses a buffer.

 @param dst_buffer
 Pointer to the first byte of the destination buffer.

 @param dst_size
 Size of the destination buffer in bytes.

 @param src_buffer
 Pointer to the first byte of the source buffer.

 @param src_size
 Size of the source buffer in bytes.

 @param scratch_buffer
 If non-null, a pointer to scratch space that the routine can use for temporary
 storage during compression.  To determine how much space to allocate for this
 scratch space, call compression_encode_scratch_buffer_size(algorithm).  Scratch space
 may be re-used across multiple (serial) calls to _encode and _decode.
 If NULL, the routine will allocate and destroy its own scratch space
 internally; this makes the function simpler to use, but may introduce a small
 amount of performance overhead.

 @param algorithm
 The compression algorithm to be used.

 @return
 The number of bytes written to the destination buffer if the input is
 is successfully compressed.  If the entire input cannot be compressed to fit
 into the provided destination buffer, or an error occurs, 0 is returned.

*/
extern size_t
compression_encode_buffer(uint8_t * __restrict dst_buffer, size_t dst_size,
                          const uint8_t * __restrict src_buffer, size_t src_size,
                          void * __restrict __nullable scratch_buffer,
                          compression_algorithm algorithm)
__API_AVAILABLE(macos(10.11), ios(9.0));

/*!

 @function compression_decode_scratch_buffer_size

 @abstract
 Get the minimum scratch buffer size for the specified compression algorithm decoder.

 @param algorithm
 The compression algorithm for which the scratch space will be used.

 @return
 The number of bytes to allocate as a scratch buffer for use to decode with the specified
 compression algorithm. This number may be 0.

*/
extern size_t
compression_decode_scratch_buffer_size(compression_algorithm algorithm)
__API_AVAILABLE(macos(10.11), ios(9.0));

/*!

 @function compression_decode_buffer
 
 @abstract
 Decompresses a buffer.
 
 @param dst_buffer
 Pointer to the first byte of the destination buffer.
 
 @param dst_size
 Size of the destination buffer in bytes.

 @param src_buffer
 Pointer to the first byte of the source buffer.

 @param src_size
 Size of the source buffer in bytes.

 @param scratch_buffer
 If non-null, a pointer to scratch space that the routine can use for temporary
 storage during decompression.  To determine how much space to allocate for this
 scratch space, call compression_decode_scratch_buffer_size(algorithm).  Scratch space
 may be re-used across multiple (serial) calls to _encode and _decode.
 If NULL, the routine will allocate and destroy its own scratch space
 internally; this makes the function simpler to use, but may introduce a small
 amount of performance overhead.

 @param algorithm
 The compression algorithm to be used.

 @return
 The number of bytes written to the destination buffer if the input is
 is successfully decompressed.  If there is not enough space in the destination
 buffer to hold the entire expanded output, only the first dst_size bytes will
 be written to the buffer and dst_size is returned.   Note that this behavior
 differs from that of compression_encode.  If an error occurs, 0 is returned.
 
*/
extern size_t
compression_decode_buffer(uint8_t * __restrict dst_buffer, size_t dst_size,
                          const uint8_t * __restrict src_buffer, size_t src_size,
                          void * __restrict __nullable scratch_buffer,
                          compression_algorithm algorithm)
__API_AVAILABLE(macos(10.11), ios(9.0));

/******************************************************************************
 * Stream (zlib-style) compression interfaces                                 *
 ******************************************************************************/

/*  The stream interfaces satisfy a number of needs for which the raw-buffer
    interfaces are unusable.  There are two critical features of the stream
    interfaces that enable these uses:
 
      * They allow encoding and decoding to be resumed from where it ended
        when the end of a source or destination block was reached.
 
      * When resuming, the new source and destination blocks need not be
        contiguous with earlier blocks in the stream; all necessary state
        to resume compression is represented by the compression_stream object.
 
    These two properties enable tasks like:
 
      * Decoding a compressed stream into a buffer with the ability to grow
        the buffer and resume decoding if the expanded stream is too large
        to fit without repeating any work.
 
      * Encoding a stream as pieces of it become available without ever needing
        to create an allocation large enough to hold all the uncompressed data.
 
    The basic workflow for using the stream interface is as follows:
 
        1. initialize the state of your compression_stream object by calling
        compression_stream_init with the operation parameter set to specify
        whether you will be encoding or decoding, and the chosen algorithm
        specified by the algorithm parameter.  This will allocate storage
        for the state that allows encoding or decoding to be resumed 
        across calls.
 
        2. set the dst_buffer, dst_size, src_buffer, and src_size fields of
        the compression_stream object to point to the next blocks to be
        processed.
 
        3. call compression_stream_process.  If no further input will be added
        to the stream via subsequent calls, finalize should be non-zero.
        If compression_stream_process returns COMPRESSION_STATUS_END, there
        will be no further output from the stream.
 
        4. repeat steps 2 and 3 as necessary to process the entire stream.
 
        5. call compression_stream_destroy to free the state object in the
        compression_stream.
 */

typedef struct {

    /*
      You are partially responsible for management of the dst_ptr,
      dst_size, src_ptr, and src_size fields.  You must initialize
      them to describe valid memory buffers before making a call to
      compression_stream_process. compression_stream_process will update
      these fields before returning to account for the bytes of the src
      and dst buffers that were successfully processed.
    */
    uint8_t       * dst_ptr;
    size_t          dst_size;
    const uint8_t * src_ptr;
    size_t          src_size;
  
    /* The stream state object is managed by the compression_stream functions.
       You should not ever directly access this field. */
    void          * __nullable state;

} compression_stream;

typedef enum {

    /* Encode to a compressed stream */
    COMPRESSION_STREAM_ENCODE = 0,
  
    /* Decode from a compressed stream */
    COMPRESSION_STREAM_DECODE = 1,
  
} compression_stream_operation;

/* Bits for the flags in compression_stream_process. */
typedef enum {

    COMPRESSION_STREAM_FINALIZE = 0x0001,

} compression_stream_flags;

/* Return values for the compression_stream functions. */
typedef enum {

    COMPRESSION_STATUS_OK     = 0,
    COMPRESSION_STATUS_ERROR  = -1,
    COMPRESSION_STATUS_END    = 1,
  
} compression_status;

/*!

 @function compression_stream_init

 @abstract
 Initialize a compression_stream for encoding (if operation is
 COMPRESSION_STREAM_ENCODE) or decoding (if operation is 
 COMPRESSION_STREAM_DECODE).

 @param stream
 Pointer to the compression_stream object to be initialized.

 @param operation
 Specifies whether the stream is to initialized for encoding or decoding.
 Must be either COMPRESSION_STREAM_ENCODE or COMPRESSION_STREAM_DECODE.

 @param algorithm
 The compression algorithm to be used.  Must be one of the values specified
 in the compression_algorithm enum.

 @discussion
 This call initializes all fields of the compression_stream to zero, except
 for state; this routine allocates storage to capture the internal state
 of the encoding or decoding process so that it may be resumed.  This
 storage is tracked via the state parameter.

 @return
 COMPRESSION_STATUS_OK if the stream was successfully initialized, or
 COMPRESSION_STATUS_ERROR if an error occurred.

*/
extern compression_status
compression_stream_init(compression_stream * stream,
                        compression_stream_operation operation,
                        compression_algorithm algorithm)
__API_AVAILABLE(macos(10.11), ios(9.0));

/*!

 @function compression_stream_process

 @abstract
 Encodes or decodes a block of the stream.

 @param stream
 Pointer to the compression_stream object to be operated on.  Before calling
 this function, you must initialize the stream object by calling
 compression_stream_init, and setting the user-managed fields to describe your
 input and output buffers. When compression_stream_process returns, those
 fields will have been updated to account for the bytes that were successfully
 encoded or decoded in the course of its operation.

 @param flags
 Binary OR of zero or more compression_stream_flags:
 
 COMPRESSION_STREAM_FINALIZE
 If set, indicates that no further input will be added to the stream, and
 thus that the end of stream should be indicated if the input block is
 completely processed.

 @discussion
 Processes the buffers described by the stream object until the source buffer
 becomes empty, or the destination buffer becomes full, or the entire stream is
 processed, or an error is encountered.

 @return
 When encoding COMPRESSION_STATUS_END is returned only if all input has been
 read from the source, all output (including an end-of-stream marker) has been
 written to the destination, and COMPRESSION_STREAM_FINALIZE bit is set.
 
 When decoding COMPRESSION_STATUS_END is returned only if all input (including
 and end-of-stream marker) has been read from the source, and all output has
 been written to the destination.
 
 COMPRESSION_STATUS_OK is returned if all data in the source buffer is consumed,
 or all space in the destination buffer is used. In that case, further calls
 to compression_stream_process are expected, providing more data in the source
 buffer, or more space in the destination buffer.
 
 COMPRESSION_STATUS_ERROR is returned if an error is encountered (if the
 encoded data is corrupted, for example).

 When decoding a valid stream, the end of stream will be detected from the contents
 of the input, and COMPRESSION_STATUS_END will be returned in that case, even if
 COMPRESSION_STREAM_FINALIZE is not set, or more input is provided.

 When decoding a corrupted or truncated stream, if COMPRESSION_STREAM_FINALIZE is not
 set to notify the decoder that no more input is coming, the decoder will not consume
 or produce any data, and return COMPRESSION_STATUS_OK.  In that case, the client code
 will call compression_stream_process again with the same state, entering an infinite loop.
 To avoid this, it is strongly advised to always set COMPRESSION_STREAM_FINALIZE when
 no more input is expected, for both encoding and decoding.

*/
extern compression_status
compression_stream_process(compression_stream * stream,
                           int flags)
__API_AVAILABLE(macos(10.11), ios(9.0));

/*!

 @function compression_stream_destroy

 @abstract
 Cleans up state information stored in a compression_stream object.

 @discussion
 Use this to free memory allocated by compression_stream_init.  After calling
 this function, you will need to re-init the compression_stream object before
 using it again.

*/
extern compression_status
compression_stream_destroy(compression_stream * stream)
__API_AVAILABLE(macos(10.11), ios(9.0));
  
#if __has_feature(assume_nonnull)
  _Pragma("clang assume_nonnull end")
#endif
#ifdef __cplusplus
} // extern "C"
#endif

#endif /* __COMPRESSION_HEADER__ */
