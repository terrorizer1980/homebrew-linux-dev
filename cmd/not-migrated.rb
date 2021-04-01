# frozen_string_literal: true

require "cli/parser"
require "formula"

module Homebrew
  module_function

  def not_migrated_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `not-migrated` [<formula>]

        Display not migrated Linux changes excluding bottles.
      EOS

      flag "--limit=",
           description: "Limit the number of non-empty diffs printed."
      flag "--homebrew-ref=",
           description: "Homebrew git ref (default `homebrew/master`)."
      flag "--linuxbrew-ref=",
           description: "Linuxbrew git ref (default `master`)."
      switch "--only-names",
             description: "Only print names of the formulae with diffs."
      switch "--sort",
             description: "Sort formulae alphabetically."

      named_args max: 1
    end
  end

  def not_migrated
    args = not_migrated_args.parse

    homebrew_ref = args.homebrew_ref || "homebrew/master"
    linuxbrew_ref = args.linuxbrew_ref || "master"

    odie "Needs git >=2.30 to work" if Utils::Git.version < Version.parse("2.30")

    CoreTap.instance.path.cd do
      counter = 0

      formulae = if args.no_named?
        Formula.select { |formula| formula.tap.core_tap? }
      else
        args.named.to_formulae
      end

      formulae = formulae.sort if args.sort?

      formulae.each do |formula|
        diff = Utils.safe_popen_read Utils::Git.path,
                                     "--no-pager", "diff",
                                     "-I", "^  revision .+", # ignore revisions
                                     "-I", "^    sha256 .+", # ignore bottle checksums
                                     "#{homebrew_ref}..#{linuxbrew_ref}",
                                     "--", formula.path.relative_path_from(Dir.pwd)
        diff.chomp!

        if diff.present?
          counter += 1
          if args.only_names?
            puts formula.name
          else
            puts diff
          end
        end

        exit if args.limit && counter == args.limit.to_i
      end
    end
  end
end
