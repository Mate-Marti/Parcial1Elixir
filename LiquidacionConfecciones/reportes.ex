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
  Funcion auxiliar Privada
  """
  defp sumar_prendas_por(lotes, clave) do
    Enum.reduce(lotes, %{}, fn lote, acumulado ->
      Map.update(acumulado, clave.(lote), lote.prendas, &(&1 + lote.prendas))
    end)
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


  @doc """
  R2
  """
  def productividad_lineas(lotes_validos, lineas) do
    prendas_por_linea = sumar_prendas_por(lotes_validos, & &1.linea)

    lineas
    |> Enum.map(fn linea ->
      prendas = Map.get(prendas_por_linea, linea.id, 0)
      %{id: linea.id, nombre: linea.nombre, prendas: prendas, productividad: prendas / linea.puestos}
    end)
    |> Enum.sort_by(& &1.productividad, :desc)
  end

  @doc """
  R3
  """
  def produccion_diaria(lotes_validos) do
    base = Map.new(@dias, fn dia -> {dia, 0} end)
    prendas_por_dia = sumar_prendas_por(lotes_validos, & &1.dia)
    Map.merge(base, prendas_por_dia)
  end

  def meta_cumplida?(prendas), do: prendas >= @meta_diaria

  def resumen_meta(produccion) do
    cumplidos = produccion |> Map.values() |> Enum.map(&meta_cumplida?/1)
    %{todos: Enum.all?(cumplidos), alguno: Enum.any?(cumplidos)}
  end

  @doc """
  R4
  """
  def ranking(liquidaciones, opciones) do
    campo = Keyword.get(opciones, :campo, :neto)
    orden = Keyword.get(opciones, :orden, :desc)
    limite = Keyword.get(opciones, :limite, length(liquidaciones))

    liquidaciones
    |> Enum.sort_by(&Map.fetch!(&1, campo), orden)
    |> Enum.take(limite)
  end


  @doc """
  R5
  """
  def lideres_por_dia(lotes_validos, confeccionistas) do
    nombres = Map.new(confeccionistas, fn c -> {c.codigo, c.nombre} end)

    Enum.map(@dias, fn dia ->
      prendas_por_confeccionista =
        lotes_validos
        |> Enum.filter(&(&1.dia == dia))
        |> sumar_prendas_por(& &1.confeccionista)

      lideres_del_dia(dia, prendas_por_confeccionista, nombres)
    end)
  end

  defp lideres_del_dia(dia, prendas_por_confeccionista, _nombres)
       when map_size(prendas_por_confeccionista) == 0 do
    %{dia: dia, prendas: 0, lideres: []}
  end
  defp lideres_del_dia(dia, prendas_por_confeccionista, nombres) do
    maximo = prendas_por_confeccionista |> Map.values() |> Enum.max()

    lideres =
      for {codigo, prendas} <- prendas_por_confeccionista, prendas == maximo do
        Map.fetch!(nombres, codigo)
      end

    %{dia: dia, prendas: maximo, lideres: Enum.sort(lideres)}
  end

  def mas_dias_en_primer_lugar(lideres_por_dia) do
    victorias =
      lideres_por_dia
      |> Enum.flat_map(& &1.lideres)
      |> Enum.frequencies()

    if map_size(victorias) == 0 do
      {0, []}
    else
      maximo = victorias |> Map.values() |> Enum.max()
      {maximo, for({nombre, n} <- victorias, n == maximo, do: nombre) |> Enum.sort()}
    end
  end


  @doc """
  R6
  """
  def porcentaje_ponderado(lotes) do
    total_prendas = lotes |> Enum.map(& &1.prendas) |> Enum.sum()
    total_defectuosas = lotes |> Enum.map(&(&1.defectos * &1.prendas)) |> Enum.sum()
    total_defectuosas / total_prendas
  end

  def promedio_simple(lotes) do
    (lotes |> Enum.map(& &1.defectos) |> Enum.sum()) / length(lotes)
  end

  def mejor_calidad(lotes_validos, confeccionistas) do
    lotes_por_codigo = Enum.group_by(lotes_validos, & &1.confeccionista)

    candidatos =
      for c <- confeccionistas,
          lotes = Map.get(lotes_por_codigo, c.codigo, []),
          length(lotes) >= @minimo_lotes_calidad do
        %{nombre: c.nombre, porcentaje: porcentaje_ponderado(lotes)}
      end

    case candidatos do
      [] -> {:error, :sin_datos}
      _ -> {:ok, Enum.min_by(candidatos, & &1.porcentaje)}
    end
  end

  @doc """
  R7
  """
  def costo_total(liquidaciones) do
    total = liquidaciones |> Enum.map(& &1.neto) |> Enum.sum()
    prendas = liquidaciones |> Enum.map(& &1.prendas) |> Enum.sum()

    promedio = if prendas == 0, do: {:error, :sin_prendas}, else: {:ok, total / prendas}

    %{total: total, prendas: prendas, promedio: promedio}
  end


  @doc """
  R8
  """
  def en_todas_las_lineas(lotes_validos, confeccionistas, lineas) do
    todas = MapSet.new(lineas, & &1.id)

    lineas_por_codigo =
      lotes_validos
      |> Enum.group_by(& &1.confeccionista, & &1.linea)
      |> Map.new(fn {codigo, ids} -> {codigo, MapSet.new(ids)} end)

    for c <- confeccionistas,
        MapSet.subset?(todas, Map.get(lineas_por_codigo, c.codigo, MapSet.new())),
        do: c.nombre
  end

  @doc """
  Funcion para llamar todos los reportes
  """
  def todos_los_reportes(lotes, confeccionistas, lineas) do
    r1(lotes, confeccionistas, lineas)
    IO.puts("\n")
    IO.inspect(productividad_lineas(lotes, lineas), label: "Productividad por línea", limit: :infinity)
    IO.puts("\n")
    produccion_diaria = produccion_diaria(lotes)
    IO.inspect(produccion_diaria, label: "Producción diaria", limit: :infinity)
    IO.inspect(resumen_meta(produccion_diaria), label: "Resumen de meta diaria cumplida", limit: :infinity)
    IO.puts("\n")
    liquidaciones = Enum.map(confeccionistas, &Liquidacion.liquidar_confeccionista(&1, lotes))
    IO.inspect(ranking(liquidaciones, campo: :neto, orden: :desc, limite: 3), label: "Ranking de liquidaciones por neto", limit: :infinity)
    IO.puts("\n")
    lideres_por_dia = lideres_por_dia(lotes, confeccionistas)
    IO.inspect(lideres_por_dia, label: "Líderes por día", limit: :infinity)
    IO.inspect(mas_dias_en_primer_lugar(lideres_por_dia), label: "Confeccionista con más días en primer lugar", limit: :infinity)
    IO.puts("\n")
    IO.inspect(mejor_calidad(lotes, confeccionistas), label: "Confeccionista con mejor calidad", limit: :infinity)
    IO.puts("\n")
    IO.inspect(costo_total(liquidaciones), label: "Costo total y promedio por prenda", limit: :infinity)
    IO.puts("\n")
    IO.inspect(en_todas_las_lineas(lotes, confeccionistas, lineas), label: "Confeccionistas que trabajaron en todas las líneas", limit: :infinity)
  end

end
