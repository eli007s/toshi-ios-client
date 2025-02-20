#import "FileUtils.h"

#import <MobileCoreServices/MobileCoreServices.h>

NSString *MimeTypeForFileExtension(NSString *fileExtension)
{
    return MimeTypeForFileUTI((__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExtension, NULL));
}

NSString *MimeTypeForFileUTI(NSString *fileUTI)
{
    NSString *mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)fileUTI, kUTTagClassMIMEType);
    if (mimeType == nil)
        mimeType = @"application/octet-stream";
    return mimeType;
}

NSString *TGTemporaryFileName(NSString *fileExtension)
{
    if (fileExtension == nil)
        fileExtension = @"bin";
    
    int64_t randomId = 0;
    arc4random_buf(&randomId, sizeof(randomId));
    
    return [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"%" PRIx64 ".%@", randomId, fileExtension]];
}
