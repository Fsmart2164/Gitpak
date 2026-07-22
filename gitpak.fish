#!/bin/fish
function get_names_of_installed
    jq -r '.[] | .name' $repos_json
end
function get_ver --argument-names name
    jq -r --arg name "$name" '.[] | select(.name==$name) | .version' $repos_json
end
function get_url --argument-names name
    jq -r --arg name "$name" '.[] | select(.name==$name) | .url' $repos_json
end
function get_current_ver --argument-names url
    git ls-remote --tags --sort=-v:refname $url | grep -v '\^{}' | head -n1 | sed 's/.*refs\/tags\///'
end

function get_input
    set -l prompt $argv[1]
    set -l possible_inputs $argv[2..(count $argv)]
    while true
        set input (read -p "echo $prompt")
        if contains $input $possible_inputs
            break
        end
    end
    echo "$input"
end

function repo_exists --argument-names name
    set -l found (jq --arg n "$name" 'any(.[]; .name == $n)' $repos_json)
    [ "$found" = true ]
end

function list_updates
    set repos (get_names_of_installed)
    for repo in $repos
        set install_ver (get_ver $repo)
        set url (get_url $repo)
        set current_ver (get_current_ver $url)
        if [ $current_ver != $install_ver ]
            echo $repo: $install_ver "-->" $current_ver
        end
    end
end

function install_package --argument-names name url i total
    if [ "$name" = "" ]; or [ "$url" = "" ]
        echo empty/bugged entry
        return
    end

    cd "$project_location/Repos"

    set exe "$project_location/Data/Install_Commands/$name.fish"
    # run install script
    echo "[$i/$total] Installing $name..."
    sudo fish $exe

    echo $name finished
end

########################################################### function line ###########################################################

set -g project_location (cat /etc/gitpak/config)
set repos_json "$project_location/Data/repos.json"
set vgitpak "v0.1.01"
cd $project_location

if set -q argv[1]
    set choice $argv[1]
else
    echo use --help for details
    return
end

if [ $choice = update ]; or [ $choice = up ]
    ### fetching all data and making list of updates
    set repos (get_names_of_installed)
    set -l updates
    for repo in $repos
        set install_ver (get_ver $repo)
        set url (get_url $repo)
        set current_ver (get_current_ver $url)

        if [ $current_ver != $install_ver ]
            echo $repo: $install_ver "-->" $current_ver
            set -a updates "$repo?$url?$current_ver"
        else
            echo $repo is up to date
        end
    end

    if not [ "$updates" = "" ]
        ### unpacking data and updating from the updates list
        set input (get_input "echo Would you like gitpak to update? [Y/n]:" Y n)
        if not [ $input = Y ]
            return
        end
        sudo rm -rf Repos
        mkdir -p Repos
        cd Repos
        set total (count $updates)
        set i 0
        for package in $updates
            set i (math $i + 1)
            set -l package (string split '?' $package)
            set name $package[1]
            set url $package[2]
            set updated_ver $package[3]

            install_package $name $url $i $total
            jq --arg url "$url" --arg version "$updated_ver" \
                '(.[] | select(.url==$url) | .version) = $version' \
                $repos_json >"$repos_json.tmp" && mv "$repos_json.tmp" $repos_json
        end
    end
else if [ $choice = install ]; or [ $choice = in ]
    ### getting url
    set clone true
    if not set -q argv[2]
        set urls (read -p "echo enter package url:' '")
        if [ "$urls" = "" ]
            exit
        end
    else
        if [ $argv[2] = --no-clone ]
            set clone false
            set urls $argv[3..(count $argv)]
        else
            set urls $argv[2..(count $argv)]
        end
    end
    set i 0
    set total (count $urls)
    for url in $urls
        set i (math $i + 1)
        ### getting attributes for json storage
        set url_segments (string split '/' $url)
        set name $url_segments[(count $url_segments)]
        if repo_exists $name
            echo $name already exits
            echo aborting...
            return
        end
        set ver (get_current_ver $url)
        ### inserting into json
        jq --arg name "$name" --arg url "$url" --arg version "$ver" \
            '. + [{"name": $name, "url": $url, "version": $version}]' \
            $repos_json >"$repos_json.tmp" && mv "$repos_json.tmp" $repos_json

        ### checking to see if install instructions are present
        set skip false
        set exe "$project_location/Data/Install_Commands/$name.fish"
        if [ -f $exe ]
            echo Install commands for $name already exist
            set input (get_input "Would you like to keep these instructions? [Y/n]: " Y n)
            if [ $input = Y ]
                set skip true
            end
        end

        if [ $skip = false ]
            ### allowing the user to install
            sudo echo "#!/bin/fish" >$exe

            cd "$project_location/Repos"

            if [ $clone = false ]
                mkdir $name
                sudo echo "mkdir $name" >>$exe
                cd $name
                sudo echo "cd $name" >>$exe
                sudo echo "### setting up isolated dir ^ do not change ###" >>$exe
                sudo echo "" >>$exe
            else
                git clone $url
                sudo echo "git clone $url" >>$exe

                cd $name
                sudo echo "cd $name" >>$exe
                sudo echo "### git repo cloning ^ do not change ###" >>$exe
                sudo echo "" >>$exe
            end
            echo
            echo
            echo
            echo
            echo "[$i/$total] now you need to install $name "
            echo when you have installed the program enter the command: DONE

            set prompt "$USER'@'$hostname '~> ' "
            while true
                set command (read -p "echo $prompt")
                if [ $command = DONE ]
                    break
                end
                echo $command >>$exe
                eval $command
            end
            cat -n $exe
            set confirm (get_input "echo 'Is this the correct install commands? [Y/n]:'" Y n)
            if not [ $confirm = Y ]
                nano $exe
            end

            sudo echo "" >>$exe
            sudo echo "### clearing used data \/ do not change ###" >>$exe
            cd $project_location/Repos/
            sudo echo "cd $project_location/Repos" >>$exe

            echo removing leftover files from $name ...
            sudo rm -rf $name
            sudo echo "sudo rm -rf $name" >>$exe

            echo $name cleaned up
        else
            install_package $name $url $i $total
        end
    end
else if [ $choice = remove ]; or [ $choice = rm ]
    if not set -q argv[2]
        set names (read -p "echo enter package name:' '")
        if [ "$name" = "" ]
            exit
        end
    else
        set names $argv[2..(count $argv)]
    end
    for name in $names
        if not repo_exists $name
            echo $name is not installed
            echo aborting...
            return
        end
        jq --arg n "$name" 'map(select(.name != $n))' $repos_json >tmp.json; and mv tmp.json $repos_json
        echo $name removed
    end
else if [ $choice = force-install ]; or [ $choice = fi ]
    if not set -q argv[2]
        exit
    else
        set names $argv[2..(count $argv)]
    end
    set i 0
    set total (count $names)
    for name in $names
        set i (math $i + 1)
        if not repo_exists $name
            echo $name is not installed
            echo aborting...
            continue
        end
        set url (get_url $name)
        install_package $name $url $i $total
    end
else if [ $choice = lu ]; or [ $choice = list-updates ]
    list_updates
else if [ $choice = list ]
    set package_names (get_names_of_installed)
    for name in $package_names
        set url (get_url $name)
        set ver (get_ver $name)
        echo "$name-$ver :$url"
    end
else if [ $choice = --help ]; or [ $choice = -h ]
    cat "$project_location/Data/help.readme"
else if [ $choice = --version ]; or [ choice = -v ]
    cat $project_location/Data/logo
    echo Gitpak version $vgitpak
else
    echo unknown command
    echo use --help for details
end

# install should be /usr/local/bin
# for later the commands for completion is 
# /usr/share/fish/completions/gitpak.fish