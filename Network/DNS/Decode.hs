-- | Decoders for DNS.
module Network.DNS.Decode (
    -- * DNS message decoders
    decodeAt
  , decodeManyAt
  , decode
  , decodeMany
  ) where

import Network.DNS.Decode.Parsers
import Network.DNS.Imports
import Network.DNS.StateBinary
import Network.DNS.Types

----------------------------------------------------------------

-- | Decoding DNS query or response.

-- | Decode an input buffer containing a single encoded DNS message.  DNS
-- /circle-arithmetic/ timestamps (e.g. in RRSIG records) are interpreted
-- at the supplied epoch time.
--
decodeAt :: Int64      -- ^ current epoch time
         -> ByteString -- ^ input encoded buffer
         -> Either DNSError DNSMessage
decodeAt t bs = fst <$> runSGetAt t getResponse bs

-- | Decode an input buffer containing a single encoded DNS message.  DNS
-- /circle-arithmetic/ timestamps (e.g. in RRSIG records) are interpreted at a
-- nominal time in the year 2078 chosen to give correct dates for timestamps
-- over a 136 year time range from the date the root zone was signed on the
-- 15th of July 2010 until the 21st of August in 2146.  Outside this range the
-- output is off by some non-zero multiple 2\^32 seconds.
--
decode :: ByteString -> Either DNSError DNSMessage
decode bs = fst <$> runSGet getResponse bs

-- | Parse many length-encoded DNS records, for example, from TCP traffic.

-- | Decode a buffer containing multiple encoded DNS messages each preceded by
-- a 16-bit length in network byte order.  DNS /circle-arithmetic/ timestamps
-- (e.g. in RRSIG records) are interpreted at the supplied epoch time.
--
decodeManyAt :: Int64      -- ^ current epoch time
             -> ByteString -- ^ input buffer
             -> Either DNSError ([DNSMessage], ByteString)
decodeManyAt t bs = decodeMParse (decodeAt t) bs

-- | Decode a buffer containing multiple encoded DNS messages each preceded by
-- a 16-bit length in network byte order.  DNS /circle-arithmetic/ timestamps
-- (e.g. in RRSIG records) are interpreted based on a nominal time in the year
-- 2078 chosen to give correct dates for DNS timestamps over a 136 year time
-- range from the date the root zone was signed on the 15th of July 2010 until
-- the 21st of August in 2146.  Outside this date range the output is off by
-- some non-zero multiple 2\^32 seconds.
--
decodeMany :: ByteString -- ^ input buffer
           -> Either DNSError ([DNSMessage], ByteString)
decodeMany bs = decodeMParse decode bs


-- | Decode multiple messages using the given parser.
--
decodeMParse :: (ByteString -> Either DNSError DNSMessage)
             -> ByteString
             -> Either DNSError ([DNSMessage], ByteString)
decodeMParse decoder bs = do
    ((bss, _), leftovers) <- runSGetWithLeftovers lengthEncoded bs
    msgs <- mapM decoder bss
    return (msgs, leftovers)
  where
    -- Read a list of length-encoded bytestrings
    lengthEncoded :: SGet [ByteString]
    lengthEncoded = many $ getInt16 >>= getNByteString
