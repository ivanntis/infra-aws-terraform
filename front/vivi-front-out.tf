output "url-cloudfront" {
    value = "${aws_cloudfront_distribution.www_distribution.domain_name}"
}
output "url-bucket" {
    value = "${aws_s3_bucket.www.website_endpoint}"
}