# typed: strict
# frozen_string_literal: true

module RubyLsp
  class GlobalState
    extend T::Sig

    sig { returns(RubyIndexer::Index) }
    attr_reader :index

    sig { returns(Store) }
    attr_reader :store

    sig { returns(URI::Generic) }
    attr_reader :workspace_uri

    sig { returns(String) }
    attr_reader :client_name

    sig { returns(T::Boolean) }
    attr_reader :supports_progress

    sig { returns(String) }
    attr_accessor :formatter

    sig { returns(T::Boolean) }
    attr_reader :experimental_features

    sig { returns(T::Hash[Symbol, RequestConfig]) }
    attr_reader :features_configuration

    sig { void }
    def initialize
      @index = T.let(RubyIndexer::Index.new, RubyIndexer::Index)
      @store = T.let(Store.new, Store)
      @workspace_uri = T.let(URI::Generic.from_path(path: Dir.pwd), URI::Generic)
      @client_name = T.let("Unknown", String)
      @supports_progress = T.let(true, T::Boolean)
      @formatter = T.let("auto", String)
      @experimental_features = T.let(false, T::Boolean)
      @features_configuration = T.let(
        {
          inlayHint: RequestConfig.new({
            enableAll: false,
            implicitRescue: false,
            implicitHashValue: false,
          }),
        },
        T::Hash[Symbol, RequestConfig],
      )
    end

    sig { params(options: T::Hash[Symbol, T.untyped]).void }
    def ingest_initialization_options(options)
      workspace_uri = options.dig(:workspaceFolders, 0, :uri)
      @workspace_uri = URI(workspace_uri) if workspace_uri

      client_name = options.dig(:clientInfo, :name)
      @client_name = client_name if client_name

      encodings = options.dig(:capabilities, :general, :positionEncodings)
      @store.encoding = if encodings.nil? || encodings.empty?
        Constant::PositionEncodingKind::UTF16
      elsif encodings.include?(Constant::PositionEncodingKind::UTF8)
        Constant::PositionEncodingKind::UTF8
      else
        encodings.first
      end

      progress = options.dig(:capabilities, :window, :workDoneProgress)
      @supports_progress = progress.nil? ? true : progress

      formatter = options.dig(:initializationOptions, :formatter) || "auto"
      @formatter = if formatter == "auto"
        DependencyDetector.instance.detected_formatter
      else
        formatter
      end

      @experimental_features = options.dig(:initializationOptions, :experimentalFeaturesEnabled) || false

      configured_hints = options.dig(:initializationOptions, :featuresConfiguration, :inlayHint)
      T.must(@features_configuration.dig(:inlayHint)).configuration.merge!(configured_hints) if configured_hints
    end

    sig { returns(String) }
    def encoding
      @store.encoding
    end

    sig { returns(String) }
    def workspace_path
      T.must(@workspace_uri.to_standardized_path)
    end
  end
end
