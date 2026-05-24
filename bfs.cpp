#include "bfs.h"
#include <chrono>

Bfs::Bfs(int nodes, int mode) : nodes(nodes)
{
    for (int i = 0; i < nodes; i++)
    {
        dists.push_back(-1);
    }

    create_graph(0.3, mode);
}

Bfs::Bfs(int v_size, int* edges, int e_size, int* offsets)
{
    for (int i = 0; i < v_size; i++)
    {
        dists.push_back(-1);
    }

    for (int i = 0; i < v_size+1; i++)
    {
        this->offsets.push_back(offsets[i]);
    }

    for (int i = 0; i < e_size; i++)
    {
        this->edges.push_back(edges[i]);
    }
}

void Bfs::create_graph(double rate, int mode)
{
    if (mode == 0) //big graph
    {
        for (int i = 0; i < nodes; i++)
        {
            offsets.push_back(edges.size());
            for (int j = 0; j < nodes; j++)
            {
                if (rand() % 100 / 100.0 <= rate && j != i)
                {
                    edges.push_back(j);
                }
            }
        }
        offsets.push_back(edges.size());
    }
    else if (mode == 1)
    {
        int l = sqrt(nodes);
        offsets.reserve(nodes+1);
        edges.reserve(nodes*4);

        for (int i = 0; i < nodes; i++)
        {
            offsets.push_back(edges.size());
            edges.push_back((i % l + 1) % l + (int(i/l)) * l);
            edges.push_back((i % l - 1 + l) % l + (int(i/l)) * l);
            edges.push_back((i % l) + ((int(i/l)+1) % l) * l);
            edges.push_back((i % l) + ((int(i/l)-1+l) % l) * l);
        }
        offsets.push_back(edges.size());
    }
    else if (mode == 2)
    {
        vector<int> degree(nodes);
        int total = 0;
        for (int i = 0; i < nodes; i++)
        {
            if (rand() % 100 < 98)
            {
                degree[i] = rand()% 2 + 2;
            }
            else
            {
                degree[i] = rand() % 400 + 100;
            }
            total += degree[i];
        }

        int offset = 0;
        offsets.reserve(nodes+1);
        edges.reserve(total+1);
        for (int i = 0; i < nodes; i++)
        {
            offsets.push_back(offset);
            for (int j = 0; j < degree[i]; j++)
            {
                edges.push_back(rand() % nodes);
            }
            offset += degree[i];

        }
        offsets.push_back(total);

    }
}

void Bfs::solve(int start)
{
    v_queue.push(start);
    dists[start] = 0;

    while (!v_queue.empty())
    {
        int u = v_queue.front();
        v_queue.pop();

        for (int i = offsets[u]; i < offsets[u+1]; i++)
        {
            if (dists[edges[i]] == -1)
            {
                dists[edges[i]] = dists[u] + 1;
                v_queue.push(edges[i]);
            }
        }
    }
    
}

void Bfs::display()
{
    for (int i = 0; i < offsets.size()-1; i++)
    {
        for (int j = offsets[i]; j < offsets[i+1]; j++)
        {
            cout<<"("<<i<<", "<<edges[j]<<")"<<endl;
        }
    }
}