require 'csv'

# Uses the same figures, date range and employee filter as the PDF extract.
class ReportCsv
  def initialize(data)
    @data = data
  end

  def render
    body = CSV.generate(col_sep: ';', row_sep: "\r\n") do |csv|
      write(csv, [@data[:title]])
      write(csv, ['Estabelecimento', @data[:establishment]])
      write(csv, ['Período', @data[:period]])
      write(csv, ['Âmbito', @data[:subtitle]])
      block(csv, 'Resumo do período', ['Indicador', 'Resultado'], @data[:stats])
      Array(@data[:sections]).each do |section|
        if section[:chart_rows]
          rows = section[:chart_rows].map { |row| [row[:label], row[:display]] }
          block(csv, section[:title], ['Data / período', 'Faturação'], rows)
        else
          block(csv, section[:title], section[:headers] || ['Indicador', 'Resultado'], section[:rows])
        end
      end
      block(csv, 'Pagamentos detalhados', ['Data', 'Hora', 'Pedido', 'Mesa', 'Funcionário', 'Método', 'Valor'], @data[:payment_rows])
      block(csv, 'Como interpretar este relatório', ['Nota'], Array(@data[:notes]).map { |note| [note] })
    end
    "\uFEFF#{body}"
  end

  private

  def block(csv, title, headers, rows)
    csv << []
    write(csv, [title])
    write(csv, headers)
    Array(rows).each { |row| write(csv, row) }
    write(csv, ['Sem dados']) if rows.blank?
  end

  def write(csv, row)
    csv << row.map { |value| value.is_a?(String) && value.match?(/\A\s*[=+@-]/) ? "'#{value}" : value }
  end
end
