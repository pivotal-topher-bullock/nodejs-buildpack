$: << 'cf_spec'
require 'spec_helper'

describe 'CF NodeJS Buildpack' do
  subject(:app) { Machete.deploy_app(app_name) }
  let(:browser) { Machete::Browser.new(app) }

  after do
    Machete::CF::DeleteApp.new.execute(app)
  end

  context 'when switching stacks while deploying the same stack' do
    subject(:app) { Machete.deploy_app(app_name, stack: 'lucid64') }
    let(:app_name) { 'node_web_app_no_vendored_dependencies' }

    it 'does cleans up the app cache' do
      expect(app).to be_running(60)

      browser.visit_path('/')
      expect(browser).to have_body('Hello, World!')

      replacement_app = Machete::App.new(app_name, Machete::Host.create, stack: 'cflinuxfs2')

      app_push_command = Machete::CF::PushApp.new
      app_push_command.execute(replacement_app)

      expect(replacement_app).to be_running(60)

      browser.visit_path('/')
      expect(browser).to have_body('Hello, World!')
      expect(app).not_to have_logged('Restoring node modules from cache')
    end
  end

  context 'when specifying a range for the nodeJS version in the package.json' do
    let(:app_name) { 'node_web_app_with_version_range' }

    it 'resolves to a nodeJS version successfully' do
      expect(app).to be_running
      expect(app).to_not have_logged 'Downloading and installing node 0.12.0'
      expect(app).to have_logged /Downloading and installing node \d+\.\d+\.\d+/

      browser.visit_path('/')
      expect(browser).to have_body('Hello, World!')
    end
  end

  context 'with an app that has vendored dependencies' do
    let(:app_name) { 'node_web_app_with_vendored_dependencies' }

    context 'with an uncached buildpack', if: Machete::BuildpackMode.online? do
      it 'successfully deploys and includes the dependencies' do
        expect(app).to be_running

        browser.visit_path('/')
        expect(browser).to have_body('Hello, World!')
      end
    end

    context 'with a cached buildpack', if: Machete::BuildpackMode.offline? do
      it 'deploys without hitting the internet' do
        expect(app).to be_running

        browser.visit_path('/')
        expect(browser).to have_body('Hello, World!')

        expect(app.host).not_to have_internet_traffic
      end
    end
  end

  context 'with an app with no vendored dependencies' do
    let(:app_name) { 'node_web_app_no_vendored_dependencies' }

    it 'successfully deploys and vendors the dependencies' do
      expect(app).to be_running
      expect(Dir).to_not exist("cf_spec/fixtures/#{app_name}/node_modules")
      expect(app).to have_file 'app/node_modules'

      browser.visit_path('/')
      expect(browser).to have_body('Hello, World!')
    end
  end
end
