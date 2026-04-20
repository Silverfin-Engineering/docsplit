module Docsplit

  # Delegates to **pdftk** in order to create bursted single pages from
  # a PDF document.
  class PageExtractor
    include ExternalProcess

    # Burst a list of pdfs into single pages, as `pdfname_pagenumber.pdf`.
    def extract(pdfs, opts)
      extract_options opts
      [pdfs].flatten.each do |pdf|
        pdf_name = File.basename(pdf, File.extname(pdf))
        page_path = ESCAPE[File.join(@output, "#{pdf_name}")] + "_%d.pdf"
        FileUtils.mkdir_p @output unless File.exist?(@output)

        cmd = if DEPENDENCIES[:pdftailor] # prefer pdftailor, but keep pdftk for backwards compatability
          "pdftailor unstitch --output #{page_path} #{ESCAPE[pdf]}"
        else
          "pdftk #{ESCAPE[pdf]} burst output #{page_path}"
        end
        begin
          run(cmd)
        ensure
          FileUtils.rm('doc_data.txt') if File.exist?('doc_data.txt')
        end
      end
    end


    private

    def extract_options(options)
      @output = options[:output] || '.'
    end

  end

end
