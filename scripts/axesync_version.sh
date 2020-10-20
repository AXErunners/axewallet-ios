#!/bin/sh

RUBY_SCRIPT=$(cat <<'END_RUBY_SCRIPT'
def ignore_exception
   begin
     yield  
   rescue Exception
   end
end

ignore_exception {
	data = YAML::load(STDIN.read)
	puts data['CHECKOUT OPTIONS']['AxeSync'][:'commit'] 
}
END_RUBY_SCRIPT
)

PODFILE_VERSION=`cat Podfile.lock | ruby -ryaml -e "$RUBY_SCRIPT"`

if [ -z "${PODFILE_VERSION}" ]; then
	echo "Updating AxeSyncCurrentCommit using LOCAL AxeSync dependency..."

    pushd "../AxeSync/"
	AXESYNC_COMMIT=`git rev-parse HEAD`
	popd

	echo "$AXESYNC_COMMIT" > AxeSyncCurrentCommit
else
	echo "Updating AxeSyncCurrentCommit using REMOTE AxeSync dependency..."
	
	echo "$PODFILE_VERSION" > AxeSyncCurrentCommit
fi
