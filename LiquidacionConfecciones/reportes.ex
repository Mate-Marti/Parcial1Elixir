defmodule Reportes do
  @meta_diaria 600
  @dias 1..6
  @minimo_lotes_calidad 3
  @motivos [
    :confeccionista_desconocido,
    :linea_desconocida,
    :dia_invalido,
    :prendas_fuera_de_rango,
    :porcentaje_invalido
  ]

  # R1. Rechazos
  @doc """
  contar_rechazos/1 recibe una lista de lotes rechazados y devuelve un mapa con la cantidad de rechazos por motivo.
  Devuelve `[{motivo, cantidad}]` con los cinco motivos en el orden de las
  reglas, incluso los que tienen cero rechazos.
  enum.frequencies/1 cuenta la frecuencia de cada motivo en la lista de rechazados,
  devolviendo un mapa con los motivos como claves y las cantidades como valores
  """
  def contar_rechazos(rechazados) do
    frecuencias = rechazados |> Enum.map(fn {_lote, motivo} -> motivo end) |> Enum.frequencies()
    Enum.map(@motivos, fn motivo -> {motivo, Map.get(frecuencias, motivo, 0)} end)
  end

  # Devuelve los lotes rechazados junto con el texto del motivo
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
        {:ok, _} ->
          nil

        {:error, motivo} ->
          # Buscamos el texto correspondiente al motivo del rechazo en el mapa de motivos
          motivo_texto = Map.get(motivos, motivo, motivo)
          {lote, motivo_texto}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Funcion auxiliar Privada
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
      |> Enum.group_by(fn {_lote, motivo} -> motivo end, fn {lote, _} -> lote end)
      |> Enum.map(fn {motivo, lista_lotes} ->
        %{
          motivo: motivo,
          cantidad: length(lista_lotes),
          lotes: lista_lotes
        }
      end)

    IO.inspect(rechazos, label: "Lotes rechazados por motivo y su cantidad", limit: :infinity)
  end

  # R2. Productividad por línea
  # recibe lotes válidos y líneas, devuelve una lista de mapas con id, nombre, prendas, productividad de cada línea, ordenadas de mayor a menor productividad. Las líneas sin lotes válidos aparecen con cero.
  # enum.map/2 itera sobre cada línea en la lista de líneas, y para cada línea l,
  # obtiene la cantidad de prendas producidas en esa línea a partir de los lotes válidos,
  # y calcula la productividad dividiendo las prendas por los puestos de la línea
  # sort_by/3 ordena la lista de resultados por el campo :productividad en orden descendente, de mayor a menor productividad
  @doc """
  R2. Productividad por línea
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

  # R3. Producción diaria y meta
  @doc "Prendas producidas en cada uno de los 6 días (cero si no hubo lotes)."
  # recibe lotes válidos y devuelve un mapa con la producción diaria (días 1 a 6)
  # sumar_prendas_por/2 acumula las prendas de los lotes válidos por día
  # enum.map/2 recorre el rango de días y arma una tupla {dia, prendas} por cada uno, con Map.get/3
  # obteniendo la cantidad de prendas del día desde el mapa de prendas por día,
  # usando 0 como valor por defecto si ese día no tuvo lotes
  # enum.into/2 convierte esa lista de tuplas en un mapa
  def produccion_diaria(lotes_validos) do
    prendas_por_dia = sumar_prendas_por(lotes_validos, & &1.dia)

    @dias
    |> Enum.map(fn dia -> {dia, Map.get(prendas_por_dia, dia, 0)} end)
    |> Enum.into(%{})
  end

  def meta_cumplida?(prendas), do: prendas >= @meta_diaria

  @doc "Resume si la meta se cumplió todos los días y si se cumplió al menos uno."
  # enum.all?/2 verifica si todos los días cumplieron la meta
  # enum.any?/2 verifica si al menos un día cumplió la meta
  # cada elemento del mapa llega como tupla {dia, prendas}
  def resumen_meta(produccion) do
    %{
      todos: Enum.all?(produccion, fn {_dia, prendas} -> meta_cumplida?(prendas) end),
      alguno: Enum.any?(produccion, fn {_dia, prendas} -> meta_cumplida?(prendas) end)
    }
  end

  # R4 y C.1. Ranking con keyword list
  @doc """
  R4. Ranking con keyword list
  Las tres líneas con Keyword.get leen las opciones, cada una con su valor por defecto.
  Orden: el case elige entre :desc y :asc, y cada rama usa un solo Enum.sort/2 con una función de comparación.
  Límite: Enum.take corta la lista al final.
  Si se llama con un :orden distinto de :desc o :asc, el case falla; el enunciado solo permite esos dos valores.
  """
  def ranking(liquidaciones, opciones) do
    campo = Keyword.get(opciones, :campo, :neto)
    orden = Keyword.get(opciones, :orden, :desc)
    limite = Keyword.get(opciones, :limite, length(liquidaciones))

    ordenadas =
      case orden do
        :desc -> Enum.sort(liquidaciones, fn a, b -> Map.get(a, campo) >= Map.get(b, campo) end)
        :asc -> Enum.sort(liquidaciones, fn a, b -> Map.get(a, campo) <= Map.get(b, campo) end)
      end

    Enum.take(ordenadas, limite)
  end

  # R5. Líder de producción por día
  @doc """
  R5
  """
  def lideres_por_dia(lotes_validos, confeccionistas) do
    nombres =
      confeccionistas
      |> Enum.map(fn c -> {c.codigo, c.nombre} end)
      |> Enum.into(%{})

    Enum.map(@dias, fn dia ->
      prendas_por_confeccionista =
        lotes_validos
        |> Enum.filter(&(&1.dia == dia))
        |> sumar_prendas_por(& &1.confeccionista)

      lideres_del_dia(dia, prendas_por_confeccionista, nombres)
    end)
  end

  # Ordena de mayor a menor con Enum.sort/2, igual que en ranking.
  # El case separa el día sin lotes ([]) del caso normal, donde la cabeza de la lista es el líder.
  # for con filtro agrega a los empatados.
  defp lideres_del_dia(dia, prendas_por_confeccionista, nombres) do
    ordenados =
      Enum.sort(prendas_por_confeccionista, fn {_c1, p1}, {_c2, p2} -> p1 >= p2 end)

    case ordenados do
      [] ->
        %{dia: dia, prendas: 0, lideres: []}

      [{_codigo, maximo} | _resto] ->
        lideres =
          for {codigo, prendas} <- ordenados, prendas == maximo do
            Map.get(nombres, codigo)
          end

        %{dia: dia, prendas: maximo, lideres: Enum.sort(lideres)}
    end
  end

  # Junta todos los líderes de los seis días en una lista con Enum.reduce y ++.
  # Enum.group_by agrupa los nombres repetidos y length cuenta los días de cada uno.
  # Se ordena igual que arriba, y el case devuelve {0, []} si no hubo líderes.
  def mas_dias_en_primer_lugar(lideres_por_dia) do
    nombres = Enum.reduce(lideres_por_dia, [], fn dia, acc -> acc ++ dia.lideres end)

    ordenados =
      nombres
      |> Enum.group_by(fn nombre -> nombre end)
      |> Enum.map(fn {nombre, apariciones} -> {nombre, length(apariciones)} end)
      |> Enum.sort(fn {_n1, d1}, {_n2, d2} -> d1 >= d2 end)

    case ordenados do
      [] ->
        {0, []}

      [{_nombre, maximo} | _resto] ->
        {maximo, Enum.sort(for({nombre, dias} <- ordenados, dias == maximo, do: nombre))}
    end
  end

  ########### PENDIENTES ##################
  # R6. Mejor calidad

  @doc """
  Porcentaje de defectos ponderado por prendas: suma(defectos × prendas) / suma(prendas).
  enum.reduce/3 acumula la suma de las prendas y la suma de defectos × prendas de cada lote
  """
  def porcentaje_ponderado(lotes) do
    total_prendas = Enum.reduce(lotes, 0, fn lote, acc -> acc + lote.prendas end)

    total_defectuosas =
      Enum.reduce(lotes, 0, fn lote, acc -> acc + lote.defectos * lote.prendas end)

    total_defectuosas / total_prendas
  end

  def promedio_simple(lotes) do
    Enum.reduce(lotes, 0, fn lote, acc -> acc + lote.defectos end) / length(lotes)
  end

  @doc """
  Confeccionista con menor porcentaje ponderado entre quienes tienen al menos
  3 lotes válidos. Devuelve `{:ok, %{nombre, porcentaje}}` o `{:error, :sin_datos}`.
  enum.group_by/2 agrupa los lotes válidos por el código del confeccionista
  enum.map/2 y Map.get/3 asocian a cada confeccionista su lista de lotes (vacía si no tiene)
  enum.filter/2 deja solo a quienes tienen el mínimo de lotes
  enum.sort/2 ordena de menor a mayor porcentaje y case con [mejor | _resto] toma el primero (la cabeza)
  """
  def mejor_calidad(lotes_validos, confeccionistas) do
    lotes_por_codigo = Enum.group_by(lotes_validos, & &1.confeccionista)

    candidatos =
      confeccionistas
      |> Enum.map(fn c -> {c, Map.get(lotes_por_codigo, c.codigo, [])} end)
      |> Enum.filter(fn {_c, lotes} -> length(lotes) >= @minimo_lotes_calidad end)
      |> Enum.map(fn {c, lotes} ->
        %{nombre: c.nombre, porcentaje: porcentaje_ponderado(lotes)}
      end)

    case Enum.sort(candidatos, fn a, b -> a.porcentaje <= b.porcentaje end) do
      [] -> {:error, :sin_datos}
      [mejor | _resto] -> {:ok, mejor}
    end
  end

  @doc """
  R7
  """
  def costo_total(liquidaciones) do
    total = Enum.reduce(liquidaciones, 0, fn liquidacion, acc -> acc + liquidacion.neto end)
    prendas = Enum.reduce(liquidaciones, 0, fn liquidacion, acc -> acc + liquidacion.prendas end)

    promedio = if prendas == 0, do: {:error, :sin_prendas}, else: {:ok, total / prendas}

    %{total: total, prendas: prendas, promedio: promedio}
  end

  # R8. Confeccionistas en todas las líneas
  @doc "Nombres de quienes tienen al menos un lote válido en cada línea de producción."
  # for recorre los confeccionistas y deja solo a quienes cumplen el filtro
  # enum.all?/2 verifica que se cumpla para todas las líneas
  # enum.any?/2 verifica que exista al menos un lote válido de ese confeccionista en esa línea
  def en_todas_las_lineas(lotes_validos, confeccionistas, lineas) do
    for c <- confeccionistas,
        Enum.all?(lineas, fn linea ->
          Enum.any?(lotes_validos, fn lote ->
            lote.confeccionista == c.codigo and lote.linea == linea.id
          end)
        end),
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
