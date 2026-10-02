defmodule Liquidacion do

  def valor_lote(lote) do

    # Calculamos el valor base del lote multiplicando la cantidad de prendas por 3200
    valor_base = lote.prendas * 3200
    # Cond se utiliza para determinar el valor final según los defectos
      cond do
        lote.defectos <= 2 -> valor_base + (valor_base * 0.07)
        lote.defectos >2 and lote.defectos <= 5 -> valor_base
        lote.defectos > 5 and lote.defectos <= 10 -> valor_base - (valor_base * 0.12)
        lote.defectos > 10 -> valor_base - (valor_base * 0.25)
      end




  end

end
