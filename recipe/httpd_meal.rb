# encoding: utf-8
require_relative 'base'

class AprRecipe < BaseRecipe
  def url
    "http://apache.mirrors.tds.net/apr/apr-#{version}.tar.gz"
  end
end

class AprIconvRecipe < BaseRecipe
  def configure_options
    [
      "--with-apr=#{@apr_path}/bin/apr-1-config"
    ]
  end

  def url
    "http://apache.mirrors.tds.net/apr/apr-iconv-#{version}.tar.gz"
  end
end

class AprUtilRecipe < BaseRecipe
  def configure_options
    [
      "--with-apr=#{@apr_path}",
      "--with-iconv=#{@apr_iconv_path}",
      '--with-crypto',
      '--with-openssl',
      '--with-mysql',
      '--with-pgsql',
      '--with-gdbm',
      '--with-ldap'
    ]
  end

  def url
    "http://apache.mirrors.tds.net/apr/apr-util-#{version}.tar.gz"
  end
end

class YAJLRecipe < BaseRecipe
  def configure
    return if configured?
    execute('configure', %W(bash configure -p #{path}))
  end

  def compile
    execute('compile', [make_cmd])
  end

  def install
    return if installed?
    execute('install', [make_cmd, 'install'])
  end

  def url
    "https://github.com/lloyd/yajl/archive/#{version}.tar.gz"
  end

  def setup_tar
    system <<-eof
      install -m 755 "#{path}/lib/libyajl.so.2" "#{@httpd_path}/lib"
    eof
  end
end

class ModSecurityRecipe < BaseRecipe
  def configure_options
    [
      "--with-apxs=#{@httpd_path}/bin/apxs",
      "--with-apr=#{@apr_path}",
      "--with-apu=#{@apr_util_path}",
      "--with-yajl=#{@yajl_path}/lib #{@yajl_path}/include"
    ]
  end

  def install
    return if installed?
    execute('install', [make_cmd, 'install', "prefix=#{path}"])
  end

  def url
    "https://www.modsecurity.org/tarball/#{version}/modsecurity-#{version}.tar.gz"
  end

  def setup_tar
    system <<-eof
      install -m 755 "#{path}/lib/mod_security2.so" "#{@httpd_path}/modules/"
    eof
  end
end

class HTTPdRecipe < BaseRecipe
  def computed_options
    [
      '--prefix=/app/httpd',
      "--with-apr=#{@apr_path}",
      "--with-apr-util=#{@apr_util_path}",
      '--enable-mpms-shared=worker event',
      '--enable-mods-shared=reallyall',
      '--disable-isapi',
      '--disable-dav',
      '--disable-dialup'
    ]
  end

  def install
    return if installed?
    execute('install', [make_cmd, 'install', "prefix=#{path}"])
  end

  def url
    "https://archive.apache.org/dist/httpd/httpd-#{version}.tar.bz2"
  end

  def archive_files
    ["#{path}/*"]
  end

  def archive_path_name
    'httpd'
  end

  def setup_tar
    system <<-eof
      cd #{path}

      rm -rf build/ cgi-bin/ error/ icons/ include/ man/ manual/ htdocs/
      rm -rf conf/extra/* conf/httpd.conf conf/httpd.conf.bak conf/magic conf/original

      mkdir -p lib
      cp "#{@apr_path}/lib/libapr-1.so.0" ./lib
      cp "#{@apr_util_path}/lib/libaprutil-1.so.0" ./lib
      mkdir -p "./lib/apr-util-1"
      cp "#{@apr_util_path}/lib/apr-util-1/"*.so ./lib/apr-util-1/
      mkdir -p "./lib/iconv"
      cp "#{@apr_iconv_path}/lib/libapriconv-1.so.0" ./lib
      cp "#{@apr_iconv_path}/lib/iconv/"*.so ./lib/iconv/
    eof
  end
end

class HTTPdMeal
  attr_reader :name, :version

  def initialize(name, version, options = {})
    @name    = name
    @version = version
    @options = options
  end

  def cook
    apr_recipe.cook
    apr_iconv_recipe.cook
    apr_util_recipe.cook

    httpd_recipe.cook
    httpd_recipe.activate

    yajl_recipe.cook
    mod_security_recipe.cook
  end

  def url
    httpd_recipe.url
  end

  def archive_files
    httpd_recipe.archive_files
  end

  def archive_path_name
    httpd_recipe.archive_path_name
  end

  def archive_filename
    httpd_recipe.archive_filename
  end

  def setup_tar
    httpd_recipe.setup_tar
    yajl_recipe.setup_tar
    mod_security_recipe.setup_tar
  end

  private

  def files_hashs
    httpd_recipe.send(:files_hashs) +
      apr_recipe.send(:files_hashs) +
      apr_iconv_recipe.send(:files_hashs) +
      apr_util_recipe.send(:files_hashs) +
      yajl_recipe.send(:files_hashs) +
      mod_security_recipe.send(:files_hashs)
  end

  def httpd_recipe
    @http_recipe ||= HTTPdRecipe.new(@name, @version, {
      apr_path: apr_recipe.path,
      apr_util_path: apr_util_recipe.path,
      apr_iconv_path: apr_iconv_recipe.path
    }.merge(DetermineChecksum.new(@options).to_h))
  end

  def apr_util_recipe
    @apr_util_recipe ||= AprUtilRecipe.new('apr-util', '1.6.1', apr_path: apr_recipe.path,
                                                                apr_iconv_path: apr_iconv_recipe.path,
                                                                md5: 'bd502b9a8670a8012c4d90c31a84955f')
  end

  def apr_iconv_recipe
    @apr_iconv_recipe ||= AprIconvRecipe.new('apr-iconv', '1.2.2', apr_path: apr_recipe.path,
                                                                   md5: '60ae6f95ee4fdd413cf7472fd9c776e3')
  end

  def apr_recipe
    @apr_recipe ||= AprRecipe.new('apr', '1.6.3', md5: '57c6cc26a31fe420c546ad2234f22db4')
  end

  def yajl_recipe
    @yajl_recipe ||= YAJLRecipe.new('yajl', '2.1.0', httpd_path: httpd_recipe.path,
                                                     md5: '6887e0ed7479d2549761a4d284d3ecb0')
  end

  def mod_security_recipe
    @mod_security_recipe ||= ModSecurityRecipe.new('mod_security', '2.9.2', apr_path: apr_recipe.path,
                                                                            apr_util_path: apr_util_recipe.path,
                                                                            yajl_path: yajl_recipe.path,
                                                                            httpd_path: httpd_recipe.path,
                                                                            sha256: '41a8f73476ec891f3a9e8736b98b64ea5c2105f1ce15ea57a1f05b4bf2ffaeb5')
  end
end
