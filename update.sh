#!/bin/bash
set -eo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

nghttp2VersionDebian="$(docker run -i --rm debian:stretch-slim bash -c 'apt-get update -qq && apt-cache show "$@"' -- "libnghttp2-dev" |tac|tac| awk -F ': ' '$1 == "Version" { print $2; exit }')"
opensslVersionDebian="$(docker run -i --rm debian:jessie-backports bash -c 'apt-get update -qq && apt-cache show "$@"' -- "openssl" |tac|tac| awk -F ': ' '$1 == "Version" { print $2; exit }')"

travisEnv=
for version in "${versions[@]}"; do
	fullVersion="$(curl -sSL --compressed "https://www-us.apache.org/dist/httpd/" | grep -E '<a href="httpd-'"$version"'[^"-]+.tar.bz2"' | sed -r 's!.*<a href="httpd-([^"-]+).tar.bz2".*!\1!' | sort -V | tail -1)"
	sha1="$(curl -fsSL "https://www-us.apache.org/dist/httpd/httpd-$fullVersion.tar.bz2.sha1" | cut -d' ' -f1)"
	(
		set -x
		sed -ri \
			-e 's/^(ENV HTTPD_VERSION) .*/\1 '"$fullVersion"'/' \
			-e 's/^(ENV HTTPD_SHA1) .*/\1 '"$sha1"'/' \
			-e 's/^(ENV NGHTTP2_VERSION) .*/\1 '"$nghttp2VersionDebian"'/' \
			-e 's/^(ENV OPENSSL_VERSION) .*/\1 '"$opensslVersionDebian"'/' \
			"$version/Dockerfile" "$version"/*/Dockerfile
	)

	for variant in alpine; do
		travisEnv='\n  - VERSION='"$version VARIANT=$variant$travisEnv"
	done
	travisEnv='\n  - VERSION='"$version$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
