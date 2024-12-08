# -*- coding:utf-8 -*-

#
# Pentomino Puzzle Solver with Elixir
#

defmodule Piece do

  def create_pieces( debug_flg ) do
    piece_def_doc = """
    +-------+-------+-------+-------+-------+-------+
    |       |   I   |  L    |  N    |       |       |
    |   F F |   I   |  L    |  N    |  P P  | T T T |
    | F F   |   I   |  L    |  N N  |  P P  |   T   |
    |   F   |   I   |  L L  |    N  |  P    |   T   |
    |       |   I   |       |       |       |       |
    +-------+-------+-------+-------+-------+-------+
    |       | V     | W     |   X   |    Y  | Z Z   |
    | U   U | V     | W W   | X X X |  Y Y  |   Z   |
    | U U U | V V V |   W W |   X   |    Y  |   Z Z |
    |       |       |       |       |    Y  |       |
    +-------+-------+-------+-------+-------+-------+
    """

    split_with_idx = &Enum.with_index( String.split( &1, &2, &3 ) )
    piece_def =
    for { line, y } <- split_with_idx.( piece_def_doc, "\n", [] ) do
      for { char, col } <- split_with_idx.( line, "", trim: true ) do
        { char, ceil( col/2 ), y  }
      end |> List.flatten()
    end |> List.flatten()
    |> Enum.reduce( %{}, fn { id, x, y }, defs ->
      Map.put( defs, id,  Map.get( defs, id, [] ) ++ [[ x,y ]]  )
    end)
#   IO.inspect( piece_def )

    "FLINPTUVWXYZ"
    |> String.split( "", trim: true )
    |> Enum.reduce( [], fn id, pieces ->
      figs = 
        for r_f <- 0..7 do
          fig = piece_def[id]
          |> Enum.map(fn [x, y] ->
            rot = Enum.slice( 0..3, 0, rem(r_f,4) )        # rotate
            [x, y] = Enum.reduce( rot, [x,y], fn _, [x, y] -> [-y, x]  end)
            if r_f < 4, do: [x, y], else: [-x, y]          # flip
          end)
          |> Enum.sort_by(fn [x, y] -> [y, x] end)         # sort
          [ x0, y0 ] = hd( fig )
          fig
          |> Enum.map(fn [x, y] -> [x - x0, y - y0] end)   # normarize
        end
        |> Enum.uniq()                                     # uniq
      if debug_flg, do: IO.inspect( figs, label: id )
      pieces ++ [ { String.to_atom( id ), figs } ]
    end)
  end

end


defmodule Helper do
  def transpose( list ) do
    Enum.zip_with( list, &Function.identity/1 )
  end
end

defmodule Board do
  defstruct width: 0, height: 0, cells: [], elems: []

  def new( o ) do
    { w, h } = { o.width, o.height }
    cells = List.duplicate( List.duplicate( :SPACE, w ), h )
    hole  = if w * h == 64, do: [ [0,0], [0,1], [1,0], [1,1] ], else: []
    elems = [
      "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
      "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
    ]
    |> Enum.map(&String.split(&1, ","))
    |> transpose()

    %Board{ width: w, height: h, cells: cells, elems: elems }
    |> Board.place( ceil(w/2) - 1, ceil(h/2) - 1, hole, "@" )
  end

  def transpose( list ) do
    Enum.zip_with( list, &Function.identity/1 )
  end

  def at( self, x, y) do
    if x >= 0 and x < self.width and y >= 0 and y < self.height do
      Enum.at( Enum.at( self.cells, y), x)
    else
      "?"
    end
  end
  
  def check( self, ox, oy, fig) do
    Enum.all?( fig, fn [x, y] -> at(self, x + ox, y + oy) == :SPACE end)
  end

  def place( self, ox, oy, fig, id ) do
    self |> Map.update!( :cells, fn cells ->
      Enum.reduce( fig, cells, fn [x,y], cells ->
        List.update_at( cells, y + oy, fn row ->
          List.update_at( row, x + ox, fn _ ->
            id
          end)
        end)
      end)
    end)
  end


  def find_space( self, x, y ) do
    if Enum.at( Enum.at( self.cells, y), x) == :SPACE do
      {x, y}
    else
      x = x + 1
      {x, y} = if x == self.width, do: {0, y + 1}, else: {x, y}
      find_space( self, x, y)
    end
  end


  def render( self ) do
    for y <- 0..self.height do
      for x <- 0..self.width do
        e =
        ( if ( at(self, x+0, y+0 ) != at(self, x+0, y-1 ) ), do: 1, else: 0 ) +
        ( if ( at(self, x+0, y-1 ) != at(self, x-1, y-1 ) ), do: 2, else: 0 ) +
        ( if ( at(self, x-1, y-1 ) != at(self, x-1, y+0 ) ), do: 4, else: 0 ) +
        ( if ( at(self, x-1, y+0 ) != at(self, x+0, y+0 ) ), do: 8, else: 0 )
        Enum.at( self.elems, e)
      end
      |> transpose()
      |> Enum.map(&Enum.join(&1, ""))
    end
    |> List.flatten()
    |> Enum.join("\n")
  end
end


defmodule Solver do
  defstruct free_pcs: [], bd: nil

  def new( o ) do
    fig_num = if o.width == o.height, do: 0, else: 1
    pieces =
      Piece.create_pieces( o.debug )
      |> Keyword.update!( :F, fn figs -> Enum.slice( figs, 0..fig_num ) end)

    %Solver{ free_pcs: pieces, bd: Board.new( o ) }
  end

  def run( self ) do
    solutions( :init )
    solve( self, 0, 0 )
  end


  defp solve( self, x, y) do
    if length( self.free_pcs ) > 0 do
      {x, y} = Board.find_space( self.bd, x, y )
      self.free_pcs |> Enum.each( fn pc ->
        next = self |> Map.update!( :free_pcs, fn list ->
          List.delete( list, pc )
        end)
        [ id, figs ] = Tuple.to_list( pc )
        figs |> Enum.each( fn fig->
          if Board.check( self.bd, x, y, fig ) do
            next |> Map.update!( :bd, fn bd ->
              Board.place( bd, x, y, fig, id )
            end)
            |> solve( x, y )
          end
        end)
      end)  # Enum.each pc
    else
      sols = solutions( :up )
      curs_up = if sols > 1, do: "\x1b[#{self.bd.height*2+2}A", else: ""
      IO.puts( curs_up <> Board.render(self.bd) <> Integer.to_string( sols ) )
    end
  end


  defp solutions( arg \\ :get ) do
    case arg do
      :init -> Agent.start_link( fn -> 0 end, name: __MODULE__)
      :get  -> Agent.get(__MODULE__, & &1)
      :up   ->
        Agent.update(__MODULE__, &(&1 + 1))
        solutions()
    end
  end


  def opt_parse( argv ) do
    # Parse the arguments
    { opts, other_args, _invalid } = argv
    |> OptionParser.parse( switches: [debug: :boolean])

    # Extract the debug flag
    debug_flg = Keyword.get(opts, :debug, false)

    # Extract size argument or set default
    size =
      other_args
      |> Enum.find(&String.match?(&1, ~r/^\d+x\d+$/))
      |> parse_size( %{ width: 6, height: 10})
    Map.merge( %{debug: debug_flg} , size )
  end

  defp parse_size(nil, default), do: default
  defp parse_size(size_str, _default) do
    size = size_str
    |> String.split("x")
#   |> Kernel.tap( fn o -> IO.inspect( o ) end )
    |> Enum.map( &String.to_integer/1 )
    %{ width: hd( size ), height: Enum.at( size, 1 ) }
  end

end  # Solver

opt = Solver.opt_parse( System.argv() )
if opt.debug, do: IO.inspect opt

Solver.new( opt ) #( width: 5, height: 12 )
|> Solver.run
