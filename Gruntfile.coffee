module.exports = (grunt) ->

  filename = "leap.networking-<%= pkg.version %>"

  grunt.initConfig
    pkg: grunt.file.readJSON("package.json")
    # note that for performance, watch does not minify. be sure to do so before shipping.
    watch: {
      options: {
        livereload: true,
        atBegin: true
      }
      coffee: {
        files: ['src/*.coffee'],
        tasks: ['default'],
        options: {
          spawn: false,
        },
      },
      html: {
        files: ['./*.html'],
        tasks: [],
        options: {
          spawn: false,
        },
      },
      grunt: {
        files: ['Gruntfile.coffee'],
        tasks: ['default']
      }
    },

    concat: {
      build: {
        src: ['src/*.coffee'],
        dest: 'build/' + filename + '.js'
      }
    }

    clean: {
      build: {
        src: ['./build/*']
      }
    }

    coffee:
      build:
        files: [{
          expand: true
          cwd: 'build/'
          src: "#{filename}.js"
          dest: 'build/'
        }
        ]

    'string-replace': {
      build: {
        files: {
          './': '*.html'
        }
        options:{
            replacements: [
              {
                pattern: /leap.networking-*\.js/
                replacement: filename + '.js'
              }
            ]
          }
        }
      }

    uglify: {
      build: {
        src: "build/#{filename}.js"
        dest: "build/#{filename}.min.js"
      }
    }

    usebanner: {
      build: {
        options: {
          banner:    '/*
                    \n * LeapJS Network - v<%= pkg.version %> - <%= grunt.template.today(\"yyyy-mm-dd\") %>
                    \n * http://github.com/leapmotion/leapjs-network/
                    \n *
                    \n * Copyright <%= grunt.template.today(\"yyyy\") %> LeapMotion, Inc
                    \n *
                    \n * Licensed under the Apache License, Version 2.0 (the "License");
                    \n * you may not use this file except in compliance with the License.
                    \n * You may obtain a copy of the License at
                    \n *
                    \n *     http://www.apache.org/licenses/LICENSE-2.0
                    \n *
                    \n * Unless required by applicable law or agreed to in writing, software
                    \n * distributed under the License is distributed on an "AS IS" BASIS,
                    \n * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
                    \n * See the License for the specific language governing permissions and
                    \n * limitations under the License.
                    \n *
                    \n */
                    \n'
        }
        src: ["build/#{filename}.js", "build/#{filename}.min.js"]
      }
    }
    connect: {
      server: {
        options: {
          port: 8000
        }
      }
    }

  require('load-grunt-tasks')(grunt);


  grunt.registerTask('serve', [
    'default',
    'connect',
    'watch',
  ]);


  grunt.registerTask('default', [
    'clean',
    'concat',
    'coffee',
    'string-replace',
    'uglify',
    'usebanner'
  ]);
