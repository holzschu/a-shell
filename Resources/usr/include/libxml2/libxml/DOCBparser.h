/*
 * Summary: old DocBook SGML parser
 * Description: interface for a DocBook SGML non-verifying parser
 * This code is DEPRECATED, and should not be used anymore.
 *
 * Copy: See Copyright for the status of this software.
 *
 * Author: Daniel Veillard
 */

#ifndef __DOCB_PARSER_H__
#define __DOCB_PARSER_H__
#include <libxml/xmlversion.h>

#ifdef LIBXML_DOCB_ENABLED

#include <libxml/parser.h>
#include <libxml/parserInternals.h>

#ifndef IN_LIBXML
#ifdef __GNUC__
#warning "The DOCBparser module has been deprecated in libxml2-2.6.0"
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define LIBXML2_DOCB_DEPRECATED
#else
#include <Availability.h>
#include <TargetConditionals.h>
#define LIBXML2_DOCB_DEPRECATED __OSX_DEPRECATED(10.4, 10.4, "Deprecated in libxml2 v2.6.0") \
                                __IOS_DEPRECATED(2.0, 2.0, "Deprecated in libxml2 v2.6.0") \
                                __TVOS_DEPRECATED(9.0, 9.0, "Deprecated in libxml2 v2.6.0") \
                                __WATCHOS_DEPRECATED(1.0, 1.0, "Deprecated in libxml2 v2.6.0")
#endif

/*
 * Most of the back-end structures from XML and SGML are shared.
 */
typedef xmlParserCtxt docbParserCtxt;
typedef xmlParserCtxtPtr docbParserCtxtPtr;
typedef xmlSAXHandler docbSAXHandler;
typedef xmlSAXHandlerPtr docbSAXHandlerPtr;
typedef xmlParserInput docbParserInput;
typedef xmlParserInputPtr docbParserInputPtr;
typedef xmlDocPtr docbDocPtr;

/*
 * There is only few public functions.
 */
XMLPUBFUN int XMLCALL
		     docbEncodeEntities(unsigned char *out,
                                        int *outlen,
                                        const unsigned char *in,
                                        int *inlen, int quoteChar) LIBXML2_DOCB_DEPRECATED;

XMLPUBFUN docbDocPtr XMLCALL
		     docbSAXParseDoc   (xmlChar *cur,
                                        const char *encoding,
                                        docbSAXHandlerPtr sax,
                                        void *userData) LIBXML2_DOCB_DEPRECATED;
XMLPUBFUN docbDocPtr XMLCALL
		     docbParseDoc      (xmlChar *cur,
                                        const char *encoding) LIBXML2_DOCB_DEPRECATED;
XMLPUBFUN docbDocPtr XMLCALL
		     docbSAXParseFile  (const char *filename,
                                        const char *encoding,
                                        docbSAXHandlerPtr sax,
                                        void *userData) LIBXML2_DOCB_DEPRECATED;
XMLPUBFUN docbDocPtr XMLCALL
		     docbParseFile     (const char *filename,
                                        const char *encoding) LIBXML2_DOCB_DEPRECATED;

/**
 * Interfaces for the Push mode.
 */
XMLPUBFUN void XMLCALL
		     docbFreeParserCtxt      (docbParserCtxtPtr ctxt) LIBXML2_DOCB_DEPRECATED;
XMLPUBFUN docbParserCtxtPtr XMLCALL
		     docbCreatePushParserCtxt(docbSAXHandlerPtr sax,
                                              void *user_data,
                                              const char *chunk,
                                              int size,
                                              const char *filename,
                                              xmlCharEncoding enc) LIBXML2_DOCB_DEPRECATED;
XMLPUBFUN int XMLCALL
		     docbParseChunk          (docbParserCtxtPtr ctxt,
                                              const char *chunk,
                                              int size,
                                              int terminate) LIBXML2_DOCB_DEPRECATED;
XMLPUBFUN docbParserCtxtPtr XMLCALL
		     docbCreateFileParserCtxt(const char *filename,
                                              const char *encoding) LIBXML2_DOCB_DEPRECATED;
XMLPUBFUN int XMLCALL
		     docbParseDocument       (docbParserCtxtPtr ctxt) LIBXML2_DOCB_DEPRECATED;

#undef LIBXML2_DOCB_DEPRECATED

#ifdef __cplusplus
}
#endif

#endif /* LIBXML_DOCB_ENABLED */

#endif /* __DOCB_PARSER_H__ */
