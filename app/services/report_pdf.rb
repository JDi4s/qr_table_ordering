require 'prawn'

class ReportPdf
  GREEN = '1F6F54'
  INK = '1E3D35'
  MUTED = '60736C'
  LINE = 'D9E4DC'

  def initialize(data)
    @data = data
  end

  def render
    Prawn::Document.new(page_size: 'A4', margin: [36, 36, 42, 36]) do |pdf|
      pdf.fill_color INK
      pdf.text 'Relatórios e caixa', size: 22, style: :bold
      pdf.move_down 4
      pdf.fill_color MUTED
      pdf.text @data[:title], size: 14, style: :bold
      pdf.text "Período: #{@data[:period]}", size: 10
      pdf.move_down 18
      draw_stats(pdf)
      pdf.move_down 18
      draw_chart(pdf) if @data[:chart_rows].present?
      pdf.move_down 18 if @data[:chart_rows].present?
      draw_table(pdf)
      draw_cash_details(pdf) if @data[:pending_tables]
      draw_footer(pdf)
    end.render
  end

  private

  def draw_stats(pdf)
    cell_width = pdf.bounds.width / 2
    @data[:stats].each_slice(2) do |pair|
      top = pdf.cursor
      pair.each_with_index do |(label, value), index|
        x = index * cell_width
        pdf.fill_color 'F5F8F4'
        pdf.fill_rectangle [x, top], cell_width - 6, 44
        pdf.fill_color LINE
        pdf.stroke_rectangle [x, top], cell_width - 6, 44
        pdf.fill_color MUTED
        pdf.text_box label.to_s, at: [x + 8, top - 8], width: cell_width - 22, height: 13, size: 8
        pdf.fill_color INK
        pdf.text_box value.to_s, at: [x + 8, top - 24], width: cell_width - 22, height: 17, size: 12, style: :bold
      end
      pdf.move_down 52
    end
  end

  def draw_chart(pdf)
    pdf.fill_color INK
    pdf.text 'Evolução / distribuição', size: 13, style: :bold
    pdf.move_down 8
    max = [@data[:chart_rows].map { |row| row[:value].to_f }.max.to_f, 1].max
    width = pdf.bounds.width - 110
    @data[:chart_rows].first(12).each do |row|
      label = row[:label].to_s
      label = "#{label[0, 24]}…" if label.length > 25
      pdf.fill_color MUTED
      pdf.text_box label, at: [0, pdf.cursor], width: 92, height: 12, size: 8
      bar_width = width * row[:value].to_f / max
      pdf.fill_color GREEN
      pdf.rounded_rectangle [102, pdf.cursor - 1], [bar_width, 2].max, 10, 3
      pdf.fill_color INK
      pdf.text_box row[:display].to_s, at: [102 + [bar_width, 2].max + 6, pdf.cursor], width: 70, height: 12, size: 8
      pdf.move_down 17
    end
  end

  def draw_table(pdf)
    return if @data[:rows].blank?
    pdf.start_new_page if pdf.cursor < 155
    pdf.fill_color INK
    pdf.text 'Detalhe', size: 13, style: :bold
    pdf.move_down 8
    width = pdf.bounds.width
    first_column = width * 0.68
    row_height = 22
    rows = [['Item', 'Valor']] + @data[:rows].first(25)
    rows.each_with_index do |row, index|
      top = pdf.cursor
      pdf.fill_color(index.zero? ? GREEN : (index.odd? ? 'F5F8F4' : 'FFFFFF'))
      pdf.fill_rectangle [0, top], width, row_height
      pdf.fill_color LINE
      pdf.stroke_rectangle [0, top], width, row_height
      pdf.stroke_line [first_column, top], [first_column, top - row_height]
      pdf.fill_color(index.zero? ? 'FFFFFF' : INK)
      pdf.text_box row[0].to_s, at: [6, top - 6], width: first_column - 12, height: 14, size: 9, style: index.zero? ? :bold : :normal
      pdf.text_box row[1].to_s, at: [first_column + 6, top - 6], width: width - first_column - 12, height: 14, size: 9, style: index.zero? ? :bold : :normal, align: :right
      pdf.move_down row_height
    end
  end

  def draw_cash_details(pdf)
    return if @data[:pending_tables].blank?
    pdf.move_down 18
    pdf.fill_color INK
    pdf.text 'Mesas por pagar', size: 13, style: :bold
    pdf.move_down 6
    pdf.fill_color MUTED
    pdf.text @data[:pending_tables].join('  ·  '), size: 9
  end

  def draw_footer(pdf)
    pdf.number_pages 'Página <page> de <total>', at: [pdf.bounds.right - 100, 0], align: :right, size: 8, color: MUTED
    pdf.go_to_page(pdf.page_count)
    pdf.fill_color MUTED
    pdf.text "Gerado em #{Time.current.strftime('%d/%m/%Y %H:%M')}", size: 8, align: :left
  end
end
