defmodule Reportes do

   @doc """
  esta función recibe una lista de lotes, una lista de confeccionistas y
  una lista de líneas, y devuelve una lista de tuplas que contienen los
  lotes rechazados junto con el motivo del rechazo.
  """
def lotes_rechazados(lotes, confeccionistas, lineas) do
  motivos = %{
    :confeccionista_desconocido => "Confeccionista desconocido",
    :linea_desconocida => "Línea desconocida",
    :dia_invalido => "Día inválido",
    :prendas_fuera_de_rango => "Prendas fuera de rango",
    :porcentaje_invalido => "Porcentaje de defectos inválido"
  }

  lotes
  |> Enum.map(fn lote ->
    case Validaciones.validar_lote(lote, confeccionistas, lineas) do
      {:ok, _} -> nil
      {:error, motivo} ->
        # Buscamos el texto correspondiente al motivo del rechazo en el mapa de motivos
        motivo_texto = Map.get(motivos, motivo, motivo)
        {lote, motivo_texto}
    end
  end)
  |> Enum.reject(&is_nil/1)
end

  @doc """
  Esta función recibe una lista de lotes, una lista de confeccionistas y una lista de líneas, y
  genera un reporte de los lotes rechazados, agrupándolos por motivo de rechazo
  y mostrando la cantidad de lotes rechazados por cada motivo.
  """
  def r1(lotes, confeccionistas, lineas) do
  rechazos =
    lotes
    |> lotes_rechazados(confeccionistas, lineas)
    |> Enum.group_by(fn {lote, motivo} -> motivo end, fn {lote, _} -> lote end)
    |> Enum.map(fn {motivo, lista_lotes} ->
      %{
        motivo: motivo,
        cantidad: length(lista_lotes),
        lotes: lista_lotes
      }
    end)

  IO.inspect(rechazos, label: "Lotes rechazados por motivo y su cantidad", limit: :infinity)
end

end
