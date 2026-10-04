# Integrantes: (escriban aquí los nombres del grupo)

defmodule Reportes do
  @moduledoc """
  Cálculos de los ocho reportes y del ranking. Todas las funciones son puras:
  reciben datos y devuelven datos; la impresión la hace `Programa`.
  """

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
  Cantidad de rechazos por motivo, a partir de `[{lote, motivo}]`.
  Devuelve `[{motivo, cantidad}]` con los cinco motivos en el orden de las
  reglas, incluso los que tienen cero rechazos.
  enum.frequencies/1 cuenta la frecuencia de cada motivo en la lista de rechazados,
  devolviendo un mapa con los motivos como claves y las cantidades como valores
  """
  def contar_rechazos(rechazados) do
    frecuencias = rechazados |> Enum.map(fn {_lote, motivo} -> motivo end) |> Enum.frequencies()
    Enum.map(@motivos, fn motivo -> {motivo, Map.get(frecuencias, motivo, 0)} end)
  end
  # R2. Productividad por línea
  @doc """
  Prendas y productividad (prendas / puestos) de cada línea, ordenadas de mayor
  a menor productividad. Las líneas sin lotes válidos aparecen con cero.
  #enum.map/2 itera sobre cada línea en la lista de líneas, y para cada línea l,
  #obtiene la cantidad de prendas producidas en esa línea a partir de los lotes válidos,
  #y calcula la productividad dividiendo las prendas por los puestos de la línea
  sort_by/3 ordena la lista de resultados por el campo :productividad en orden descendente, de mayor a menor productividad
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

  # ---------------------------------------------------------------
  # R3. Producción diaria y meta
  # ---------------------------------------------------------------

  @doc "Prendas producidas en cada uno de los 6 días (cero si no hubo lotes)."
#map.new/2 crea un mapa base con los días del 1 al 6 como claves y 0 como valor inicial
#map.merge/2 combina el mapa base con otro mapa que contiene la suma de prendas por día, obtenida a partir de los lotes válidos
  def produccion_diaria(lotes_validos) do
    base = Map.new(@dias, fn dia -> {dia, 0} end)
    prendas_por_dia = sumar_prendas_por(lotes_validos, & &1.dia)
    Map.merge(base, prendas_por_dia)
  end

  @doc "Indica si las prendas de un día alcanzan la meta del taller."
  def meta_cumplida?(prendas), do: prendas >= @meta_diaria

  @doc "Resume si la meta se cumplió todos los días y si se cumplió al menos uno."
  #map.values/1 obtiene los valores del mapa de producción diaria, que representan la cantidad de prendas producidas en cada día
  #enum.any?/2 verifica si al menos un día cumplió la meta, y enum.all?/2 verifica si todos los días cumplieron la meta

  def resumen_meta(produccion) do
    cumplidos = produccion |> Map.values() |> Enum.map(&meta_cumplida?/1)
    %{todos: Enum.all?(cumplidos), alguno: Enum.any?(cumplidos)}
  end

  # ---------------------------------------------------------------
  # R4 y C.1. Ranking con keyword list
  # ---------------------------------------------------------------

  @doc """
  Ordena las liquidaciones según opciones (keyword list):

  - `:campo`: `:neto` (predeterminado), `:prendas` o `:bruto`
  - `:orden`: `:desc` (predeterminado) o `:asc`
  - `:limite`: entero positivo; por defecto, todos

  Si una opción se repite (`campo: :prendas, campo: :neto`), `Keyword.get/3`
  devuelve la PRIMERA aparición.
  keyword.get/3 obtiene el valor de la opción especificada en la lista de opciones, o un valor predeterminado si no se encuentra
  enum.sort_by/3 ordena la lista de liquidaciones según el campo especificado y el orden (ascendente o descendente)
  enum.take/2 toma los primeros n elementos de la lista ordenada, donde n es el límite especificado en las opciones
  """
  def ranking(liquidaciones, opciones) do
    campo = Keyword.get(opciones, :campo, :neto)
    orden = Keyword.get(opciones, :orden, :desc)
    limite = Keyword.get(opciones, :limite, length(liquidaciones))

    liquidaciones
    |> Enum.sort_by(&Map.fetch!(&1, campo), orden)
    |> Enum.take(limite)
  end

  # ---------------------------------------------------------------
  # R5. Líder de producción por día
  # ---------------------------------------------------------------

  @doc """
  Confeccionista(s) con más prendas cada día. Devuelve una lista con un mapa
  `%{dia, prendas, lideres}` por día; `lideres` es `[]` si no hubo lotes válidos.
  #&.dia accede al valor del campo dia del mapa, que representa el día de producción del lote
  #enum.group_by/2 agrupa los lotes por día, creando un mapa donde las claves son los días y
  #los valores son listas de lotes correspondientes a cada día
  map.new/2 crea un mapa de nombres de confeccionistas a partir de la lista de confeccionistas, donde las claves son los códigos y los valores son los nombres
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
#map_size/1 devuelve el tamaño del mapa de prendas por confeccionista, que representa la cantidad de confeccionistas que produjeron prendas en ese día
  defp lideres_del_dia(dia, prendas_por_confeccionista, _nombres)
       when map_size(prendas_por_confeccionista) == 0 do
    %{dia: dia, prendas: 0, lideres: []}
  end
#map.values/1 obtiene los valores del mapa de prendas por confeccionista, que representan la cantidad de prendas producidas por cada
#confeccionista en ese día y enum.max/1 devuelve el valor máximo de la lista de prendas, que representa la cantidad máxima de prendas
#producidas por un confeccionista en ese día
#map.fetch!/2 obtiene el nombre del confeccionista correspondiente al código del confeccionista que produjo la cantidad máxima de prendas
#en ese día y enum.sort/1 ordena alfabéticamente la lista de nombres de los confeccionistas que produjeron la cantidad máxima de prendas
#en ese día
  defp lideres_del_dia(dia, prendas_por_confeccionista, nombres) do
    maximo = prendas_por_confeccionista |> Map.values() |> Enum.max()

    lideres =
      for {codigo, prendas} <- prendas_por_confeccionista, prendas == maximo do
        Map.fetch!(nombres, codigo)
      end

    %{dia: dia, prendas: maximo, lideres: Enum.sort(lideres)}
  end

  @doc """
  Quién ocupó el primer lugar más días. Devuelve `{dias, nombres}`;
  si hay empate, incluye a todos los empatados. Sin líderes: `{0, []}`.
  enum.flat_map/2 aplana la lista de líderes por día, obteniendo una lista de nombres de confeccionistas
  #que ocuparon el primer lugar en cada día y enum.frequencies/1 cuenta la frecuencia de cada nombre en la lista de líderes,
  #devolviendo un mapa con los nombres como claves y las cantidades como valores
  map_size/1 devuelve el tamaño del mapa de victorias, que representa la cantidad de confeccionistas que ocuparon el primer lugar en algún día
  map.values/1 obtiene los valores del mapa de victorias, que representan la cantidad de días en los que cada confeccionista ocupó el primer lugar,
  #y enum.max/1 devuelve el valor máximo de la lista de victorias, que representa la mayor cantidad de
  "días en los que un confeccionista ocupó el primer lugar
  """
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
  # R6. Mejor calidad
  @doc """
  Porcentaje de defectos ponderado por prendas: suma(defectos × prendas) / suma(prendas).
  #enum.map/2 itera sobre cada lote en la lista de lotes, y para cada lote, calcula el producto de defectos y prendas
  #enum.sum/1 calcula la suma de los valores de una lista, en este caso, la suma de defectos ponderados por prendas y la suma de prendas
  """
  def porcentaje_ponderado(lotes) do
    total_prendas = lotes |> Enum.map(& &1.prendas) |> Enum.sum()
    total_defectuosas = lotes |> Enum.map(&(&1.defectos * &1.prendas)) |> Enum.sum()
    total_defectuosas / total_prendas
  end

  @doc "Promedio simple de los porcentajes de defectos (para comparar con el ponderado)."
  def promedio_simple(lotes) do
    (lotes |> Enum.map(& &1.defectos) |> Enum.sum()) / length(lotes)
  end

  @doc """
  Confeccionista con menor porcentaje ponderado entre quienes tienen al menos
  3 lotes válidos. Devuelve `{:ok, %{nombre, porcentaje}}` o `{:error, :sin_datos}`.
  enum.group_by/2 agrupa los lotes válidos por el código del confeccionista, creando un mapa
  donde las claves son los códigos y los valores son listas de lotes
  #map.get/3 obtiene la lista de lotes válidos correspondientes al confeccionista actual, o una lista vacía si no hay lotes válidos
  """
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

  # ---------------------------------------------------------------
  # R7. Costo total
  # ---------------------------------------------------------------

  @doc """
  Total pagado por el taller y costo promedio por prenda válida.
  `promedio` es `{:ok, valor}` o `{:error, :sin_prendas}`.

  """
  def costo_total(liquidaciones) do
    total = liquidaciones |> Enum.map(& &1.neto) |> Enum.sum()
    prendas = liquidaciones |> Enum.map(& &1.prendas) |> Enum.sum()

    promedio = if prendas == 0, do: {:error, :sin_prendas}, else: {:ok, total / prendas}

    %{total: total, prendas: prendas, promedio: promedio}
  end
  # R8. Confeccionistas en todas las líneas

  @doc "Nombres de quienes tienen al menos un lote válido en cada línea de producción."
  #mapset.new/2 crea un conjunto de todas las líneas a partir de la lista de líneas, utilizando el campo id como clave
  #enum.group_by/2 agrupa los lotes válidos por el código del confeccionista, creando un mapa donde
  #las claves son los códigos y los valores son listas de lotes
  #map.new/2 crea un mapa de nombres de confeccionistas a partir de la lista de confeccionistas, donde las claves son los códigos
  #y los valores son los nombres
  #map.get/3 obtiene la lista de lotes válidos correspondientes al confeccionista actual, o una lista vacía si no hay lotes válidos
  #mapset.new/2 crea un conjunto de líneas a partir de la lista de lotes válidos del confeccionista, utilizando el campo linea como clave
  #mapset.subset?/2 verifica si el conjunto de todas las líneas es un subconjunto
  #del conjunto de líneas del confeccionista, es decir, si el confeccionista tiene al menos un lote válido en cada línea
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

  # ---------------------------------------------------------------
  # C.2. Combinar con el taller aliado
  # ---------------------------------------------------------------

  @doc """
  Combina la producción diaria con la de un taller aliado sumando las prendas
  de los días presentes en ambos mapas. Los días que están en un solo mapa se
  conservan tal cual.
  #map.merge/3 combina los dos mapas de producción diaria, sumando las prendas de los días presentes en ambos mapas
  """
  def combinar_produccion(produccion, taller_aliado) do
    Map.merge(produccion, taller_aliado, fn _dia, propias, aliadas -> propias + aliadas end)
  end

  # ---------------------------------------------------------------
  # Apoyo privado
  # ---------------------------------------------------------------

  # Suma las prendas de los lotes agrupándolos por la clave que devuelve `clave`.
  #enum.reduce/3 itera sobre cada lote en la lista de lotes, y para cada lote, actualiza el acumulado sumando las prendas del lote al
  #valor correspondiente a la clave obtenida mediante
  #map.update/4 actualiza el valor del acumulado para la clave obtenida mediante la función clave,
  #sumando las prendas del lote al valor existente o inicializando con las prendas del lote si la clave no existe en el acumulado
  defp sumar_prendas_por(lotes, clave) do
    Enum.reduce(lotes, %{}, fn lote, acumulado ->
      Map.update(acumulado, clave.(lote), lote.prendas, &(&1 + lote.prendas))
    end)
  end
end
