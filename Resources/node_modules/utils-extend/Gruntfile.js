module.exports = function(grunt) {
  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.initConfig({
    jshint: {
      all: [
        'test/**/*.js',
        './*.js'
      ]
    }
  });
};